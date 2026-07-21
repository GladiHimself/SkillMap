# ── DB Subnet Group ────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name = "${var.project_name}-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── DB Parameter Group ─────────────────────────────────────────
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project_name}-postgres-params"
  family = "postgres16"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name    = "${var.project_name}-postgres-params"
    Project = var.project_name
  }
}

# ── RDS Instance ───────────────────────────────────────────────
resource "aws_db_instance" "postgres" {

  identifier = "${var.project_name}-postgres"
  db_name    = var.db_name

  engine         = "postgres"
  engine_version = var.postgres_version

  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"

  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  parameter_group_name    = aws_db_parameter_group.postgres.name
  skip_final_snapshot     = true
  backup_retention_period = 0

  tags = {
    Name        = "${var.project_name}-postgres"
    Project     = var.project_name
    Environment = var.environment
  }
}