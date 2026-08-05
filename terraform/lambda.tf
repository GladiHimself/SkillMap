# ── IAM Role for Lambda ────────────────────────────────────────
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-lambda-role"
    Project = var.project_name
  }
}

# ── Lambda Permissions Policy ──────────────────────────────────
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Permissions for SkillMap resume processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.resume_queue.arn
      },
      {
        Sid      = "S3ReadAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.resumes.arn,
          "${aws_s3_bucket.resumes.arn}/*"
        ]
      },
      {
        Sid      = "BedrockAccess"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:ap-south-1::foundation-model/meta.llama3-8b-instruct-v1:0"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.notifications.arn
      },
      {
        # NEW — Lambda needs to read DB credentials from Secrets Manager
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        # NEW — Lambda inside VPC needs ENI permissions to create
        # network interfaces in your private subnets
        Sid    = "VPCAccess"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ── Lambda Layer for psycopg2 ──────────────────────────────────
# psycopg2 needs compiled C binaries for Amazon Linux
# Built in Step 1 using Docker — stored as a layer
data "archive_file" "psycopg2_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/layers/psycopg2"
  output_path = "${path.module}/../lambda/layers/psycopg2.zip"
}

resource "aws_lambda_layer_version" "psycopg2" {
  layer_name          = "${var.project_name}-psycopg2"
  filename            = data.archive_file.psycopg2_layer_zip.output_path
  source_code_hash    = data.archive_file.psycopg2_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.12"]

  description = "psycopg2-binary for PostgreSQL connections from Lambda"
}

# ── Package Lambda Code ────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/resume_processor"
  output_path = "${path.module}/../lambda/resume_processor.zip"
}

# ── Lambda Function ────────────────────────────────────────────
resource "aws_lambda_function" "resume_processor" {
  function_name = "${var.project_name}-resume-processor"
  description   = "Processes resumes using AWS Bedrock Claude Haiku"
  depends_on = [aws_iam_role_policy_attachment.lambda_policy]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256

  # Attach the psycopg2 layer
  layers = [aws_lambda_layer_version.psycopg2.arn]

  # NEW — Place Lambda inside VPC so it can reach RDS
  # Lambda needs to be in the same VPC as RDS to connect
  vpc_config {
    subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.app.id]
  }

  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.notifications.arn
      S3_BUCKET_NAME   = aws_s3_bucket.resumes.bucket
      AWS_REGION_NAME  = var.aws_region
      ENVIRONMENT      = var.environment
      DB_SECRET_NAME   = "${var.project_name}/${var.environment}/db-credentials"
    }
  }

  tags = {
    Name    = "${var.project_name}-resume-processor"
    Project = var.project_name
  }
}

# ── SQS Event Source Mapping ───────────────────────────────────
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.resume_queue.arn
  function_name    = aws_lambda_function.resume_processor.arn
  batch_size       = 1
  enabled          = true
}

# ── CloudWatch Log Group ───────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-resume-processor"
  retention_in_days = 7

  tags = { Project = var.project_name }
}