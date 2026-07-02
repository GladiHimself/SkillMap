# Tell Terraform which cloud provider to use
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # use AWS provider version 5.x
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region  # ap-south-1 (Mumbai)
}

# ── S3 Bucket for resume storage ──────────────────────────────
resource "aws_s3_bucket" "resumes" {
  # Bucket names must be globally unique across all of AWS
  bucket = "${var.project_name}-resumes-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"   # always tag IaC resources
  }
}

# Block all public access — resumes are private documents
resource "aws_s3_bucket_public_access_block" "resumes" {
  bucket = aws_s3_bucket.resumes.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning — keeps old versions of uploaded resumes
resource "aws_s3_bucket_versioning" "resumes" {
  bucket = aws_s3_bucket.resumes.id

  versioning_configuration {
    status = "Enabled"
  }
}