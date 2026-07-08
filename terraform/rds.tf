# ── DB Subnet Group ────────────────────────────────────────────
# A container that tells RDS "you can live in these subnets"
# AWS requires subnets in at least 2 different AZs
resource "aws_db_subnet_group" "main" {
  name = "${var.project_name}-db-subnet-group"

  # Reference our private subnets from vpc.tf
  # RDS will never go into public subnets
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
# A settings file for PostgreSQL
# Creating our own means we can tune it later without
# destroying and recreating the database
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project_name}-postgres-params"
  family = "postgres16"  # must match your postgres version

  # Log any query that takes longer than 1 second
  # Useful for finding slow queries later
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # milliseconds
  }

  tags = {
    Name    = "${var.project_name}-postgres-params"
    Project = var.project_name
  }
}

# ── RDS Instance ───────────────────────────────────────────────
# The actual PostgreSQL database
resource "aws_db_instance" "postgres" {

  # ── Identity ──────────────────────────────────────────────
  identifier = "${var.project_name}-postgres"  # name in AWS console
  db_name    = var.db_name                     # database name inside postgres

  # ── Engine ────────────────────────────────────────────────
  engine         = "postgres"           # which database engine
  engine_version = var.postgres_version # 16.4

  # ── Size ──────────────────────────────────────────────────
  instance_class    = var.db_instance_class  # db.t3.micro = free tier
  allocated_storage = 20                     # 20 GB minimum for PostgreSQL
  storage_type      = "gp2"                  # general purpose SSD

  # ── Credentials ───────────────────────────────────────────
  username = var.db_username  # master username
  password = var.db_password  # from tfvars (gitignored)

  # ── Network ───────────────────────────────────────────────
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # never expose DB to internet

  # ── Settings ──────────────────────────────────────────────
  parameter_group_name = aws_db_parameter_group.postgres.name
  skip_final_snapshot  = true  # don't save snapshot on destroy
                               # fine for dev, set false in prod

  # ── Backups ───────────────────────────────────────────────
  backup_retention_period = 0  # disable backups for dev
                               # saves money, enable in prod

  tags = {
    Name        = "${var.project_name}-postgres"
    Project     = var.project_name
    Environment = var.environment
  }
}