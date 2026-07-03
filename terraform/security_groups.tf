# ── Security Group: ECS App ────────────────────────────────────
# Rules for your Spring Boot containers
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for SkillMap Spring Boot app"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP traffic on port 8080 from anywhere inside VPC
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Spring Boot app port"
  }

  # Allow all outbound traffic
  # App needs to call S3, SQS, SNS, Bedrock
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name    = "${var.project_name}-app-sg"
    Project = var.project_name
  }
}

# ── Security Group: RDS Database ───────────────────────────────
# Rules for your PostgreSQL database
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for SkillMap RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  # Only allow PostgreSQL traffic (5432) FROM the app security group
  # NOT from the internet — database is completely private
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "PostgreSQL from app only"
  }

  # Allow all outbound (for RDS to send responses back)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
  }
}

# ── Security Group: Load Balancer ──────────────────────────────
# Rules for the Application Load Balancer (used on Day 16)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Accept HTTP from anywhere on the internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  # Accept HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}