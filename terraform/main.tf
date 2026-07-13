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

# ── S3 Event Notification ──────────────────────────────────────
# When a file is uploaded to S3, automatically send event to SQS
# This is what kicks off the entire AI processing pipeline
resource "aws_s3_bucket_notification" "resume_upload" {
  bucket = aws_s3_bucket.resumes.id

  queue {
    # Which SQS queue to notify
    queue_arn = aws_sqs_queue.resume_queue.arn

    # Which S3 events trigger the notification
    events = ["s3:ObjectCreated:*"]  # any upload (PUT, POST, COPY)

    # Only trigger for PDF files
    # Prevents notifications for thumbnails or temp files
    filter_suffix = ".pdf"
  }

  # S3 notification needs the queue policy to exist first
  # Otherwise S3 can't verify it has permission to send
  depends_on = [aws_sqs_queue_policy.resume_queue]
}