# ── Data Source: Current AWS Account ──────────────────────────
data "aws_caller_identity" "current" {}

# ── IAM Policy: S3 Access ──────────────────────────────────────
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Allows SkillMap app to read and write resumes in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ResumeAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-resumes-${var.environment}",
          "arn:aws:s3:::${var.project_name}-resumes-${var.environment}/*"
        ]
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── IAM Policy: ECS Task Bedrock Access ─────────────────────────
# Allows Spring Boot (running in ECS) to call Bedrock Llama 3
# for job description skill extraction
resource "aws_iam_policy" "ecs_bedrock_access" {
  name        = "${var.project_name}-ecs-bedrock-policy"
  description = "Allows ECS Spring Boot task to call Bedrock Llama 3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockAccess"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:ap-south-1::foundation-model/meta.llama3-8b-instruct-v1:0"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── IAM Role: ECS Task Role ────────────────────────────────────
resource "aws_iam_role" "ecs_task_role" {
  name        = "${var.project_name}-ecs-task-role"
  description = "Role assumed by SkillMap ECS tasks"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSTasksTrustPolicy"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── IAM Role: ECS Execution Role ──────────────────────────────
resource "aws_iam_role" "ecs_execution_role" {
  name        = "${var.project_name}-ecs-execution-role"
  description = "Role used by ECS agent to pull images and write logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ecs-execution-role"
    Project = var.project_name
  }
}

# ── Attach S3 Policy to Task Role ─────────────────────────────
resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# ── Attach Bedrock Policy to Task Role ─────────────────────────
resource "aws_iam_role_policy_attachment" "ecs_task_bedrock" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_bedrock_access.arn
}

# ── Attach AWS Managed Policy to Execution Role ────────────────
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach secrets access policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_secrets" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Execution role needs Secrets Manager access
resource "aws_iam_role_policy_attachment" "ecs_execution_secrets" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# ── IAM User for GitHub Actions ────────────────────────────────
resource "aws_iam_user" "github_actions" {
  name = "${var.project_name}-github-actions"

  tags = {
    Name    = "${var.project_name}-github-actions"
    Project = var.project_name
  }
}

# ── IAM Policy: GitHub Actions Deployment Permissions ──────────
resource "aws_iam_policy" "github_actions_deploy" {
  name        = "${var.project_name}-github-actions-policy"
  description = "Permissions for GitHub Actions to push images and deploy to ECS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSDeploy"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "github_actions" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

# ── Access Key for GitHub Actions ──────────────────────────────
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

# ── IAM Policy: ECS Task SNS Access ─────────────────────────────
# Allows Spring Boot (in ECS) to publish match score notifications
resource "aws_iam_policy" "ecs_sns_access" {
  name        = "${var.project_name}-ecs-sns-policy"
  description = "Allows ECS Spring Boot task to publish to SNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_sns" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_sns_access.arn
}