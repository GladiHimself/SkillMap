# ── ECR Repository ─────────────────────────────────────────────
# Private Docker registry for SkillMap Spring Boot image
# ECS Fargate pulls the image from here on deployment
resource "aws_ecr_repository" "skillmap" {
  name                 = var.project_name
  force_delete         = true 
  image_tag_mutability = "MUTABLE"
  # MUTABLE means you can overwrite tags like "latest"
  # IMMUTABLE would require unique tags every time

  # Scan images for security vulnerabilities on push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = var.project_name
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── ECR Lifecycle Policy ───────────────────────────────────────
# Automatically delete old images to save storage costs
# Keep only the last 10 images — old ones deleted automatically
resource "aws_ecr_lifecycle_policy" "skillmap" {
  repository = aws_ecr_repository.skillmap.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}