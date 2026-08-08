# ── Data Source: Current AWS Account ──────────────────────────
# Reads your AWS account ID dynamically
# So you don't hardcode it — works for any AWS account
data "aws_caller_identity" "current" {}

# ── IAM Policy: S3 Access ──────────────────────────────────────
# Defines exactly what S3 actions the app is allowed to do
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Allows SkillMap app to read and write resumes in S3"

  # Policy document written in JSON inside HCL
  # jsonencode() converts HCL map syntax into proper JSON
  policy = jsonencode({
    Version = "2012-10-17"   # always this date — it's the policy language version
    Statement = [
      {
        Sid    = "S3ResumeAccess"   # statement ID — just a label
        Effect = "Allow"            # Allow or Deny

        # Which S3 actions are allowed
        Action = [
          "s3:PutObject",      # upload a file
          "s3:GetObject",      # download a file
          "s3:DeleteObject",   # delete a file
          "s3:ListBucket"      # list files in bucket
        ]

        # Which resources these actions apply to
        Resource = [
          # The bucket itself (needed for ListBucket)
          "arn:aws:s3:::${var.project_name}-resumes-${var.environment}",
          # Everything inside the bucket (needed for Put/Get/Delete)
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

# ── IAM Role: ECS Task Role ────────────────────────────────────
# This is the role your Spring Boot containers will assume
# The trust policy says: "only ECS tasks can use this role"
resource "aws_iam_role" "ecs_task_role" {
  name        = "${var.project_name}-ecs-task-role"
  description = "Role assumed by SkillMap ECS tasks"

  # Trust policy — who is allowed to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSTasksTrustPolicy"
        Effect = "Allow"

        # The principal is who can assume this role
        Principal = {
          Service = "ecs-tasks.amazonaws.com"  # only ECS tasks
        }

        Action = "sts:AssumeRole"  # the action of assuming a role
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
# Different from task role — this one is used by ECS itself
# to pull your Docker image from ECR and write logs to CloudWatch
# Your app code never uses this role directly
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
# Connects the S3 policy to the ECS task role
# Without this attachment, the role exists but has no permissions
resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# ── Attach AWS Managed Policy to Execution Role ────────────────
# AWS provides this pre-built policy for ECS execution roles
# It covers ECR image pulls and CloudWatch log writes
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  #             ↑ this is an AWS-managed policy — AWS maintains it
}

# Attach secrets access policy to ECS task role
# Now your Spring Boot containers can read Secrets Manager
resource "aws_iam_role_policy_attachment" "ecs_task_secrets" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Execution role needs Secrets Manager access
# to inject secrets into the container at startup
resource "aws_iam_role_policy_attachment" "ecs_execution_secrets" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}