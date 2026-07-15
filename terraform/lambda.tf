# ── IAM Role for Lambda ────────────────────────────────────────
# Lambda needs its own role — different from ECS task role
# Trust policy allows Lambda (not ECS) to assume this role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"  # Lambda can assume this role
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-lambda-role"
    Project = var.project_name
  }
}

# ── Lambda Permissions Policy ──────────────────────────────────
# Everything Lambda needs to do its job
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Permissions for SkillMap resume processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs — Lambda must be able to write logs
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # SQS — read messages from queue and delete after processing
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.resume_queue.arn
      },
      {
        # S3 — read uploaded resumes
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
            "s3:GetObject",
            "s3:ListBucket"    # ← add this
        ]
        Resource = [
            "${aws_s3_bucket.resumes.arn}",    # ← bucket itself (for ListBucket)
            "${aws_s3_bucket.resumes.arn}/*"   # ← objects inside (for GetObject)
        ]
       },
      {
        # Bedrock — call Claude Haiku model
        Sid    = "BedrockAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:ap-south-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
      },
      {
        # SNS — publish notifications
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.notifications.arn
      }
    ]
  })
}

# Attach policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ── Package Lambda Code ────────────────────────────────────────
# Terraform zips your Python code before uploading to Lambda
# source_dir: where your Python files are
# output_path: where to save the zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/resume_processor"
  output_path = "${path.module}/../lambda/resume_processor.zip"
}

# ── Lambda Function ────────────────────────────────────────────
resource "aws_lambda_function" "resume_processor" {
  function_name = "${var.project_name}-resume-processor"
  description   = "Processes resumes using AWS Bedrock Claude Haiku"

  # The zipped code package
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # source_code_hash detects when code changes → triggers Lambda update

  # Which role Lambda runs as
  role = aws_iam_role.lambda_role.arn

  # Python file name (handler.py) and function name (lambda_handler)
  handler = "handler.lambda_handler"
  runtime = "python3.12"

  # How long Lambda can run before timing out
  # Resume processing + AI call can take 30-60 seconds
  timeout = 120  # 2 minutes

  # Memory — more memory = faster CPU too in Lambda
  memory_size = 256  # MB

  # Environment variables — accessible via os.environ in Python
  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.notifications.arn
      S3_BUCKET_NAME   = aws_s3_bucket.resumes.bucket
      AWS_REGION_NAME  = var.aws_region
      ENVIRONMENT      = var.environment
    }
  }

  tags = {
    Name    = "${var.project_name}-resume-processor"
    Project = var.project_name
  }
}

# ── SQS Event Source Mapping ───────────────────────────────────
# Connects SQS to Lambda
# Lambda automatically polls SQS and calls handler for new messages
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.resume_queue.arn
  function_name    = aws_lambda_function.resume_processor.arn

  # How many messages Lambda receives at once
  # Start with 1 — process one resume at a time
  batch_size = 1

  # Only trigger Lambda when at least 1 message is in queue
  enabled = true
}

# ── CloudWatch Log Group ───────────────────────────────────────
# Explicitly create log group so we control retention
# Without this, Lambda creates it with infinite retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-resume-processor"
  retention_in_days = 7  # keep logs for 7 days — saves cost

  tags = {
    Project = var.project_name
  }
}