# Outputs print useful info after terraform apply
# Reference these in your Spring Boot config later

output "s3_bucket_name" {
  description = "Name of the S3 bucket for resumes"
  value       = aws_s3_bucket.resumes.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.resumes.arn
}

# VPC outputs — referenced by RDS and ECS later
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for Load Balancer"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs for RDS and ECS"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "app_security_group_id" {
  description = "Security group ID for the app"
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

# RDS outputs — Spring Boot needs the endpoint to connect
output "rds_endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_db_name" {
  description = "Database name inside PostgreSQL"
  value       = aws_db_instance.postgres.db_name
}

# IAM outputs — ECS task definition needs these ARNs on Day 16
output "ecs_task_role_arn" {
  description = "ARN of the ECS task role (used by your app)"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role (used by ECS agent)"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "s3_access_policy_arn" {
  description = "ARN of the S3 access policy"
  value       = aws_iam_policy.s3_access.arn
}