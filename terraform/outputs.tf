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