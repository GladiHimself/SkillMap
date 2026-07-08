# Variables make your Terraform reusable across environments
# Values come from terraform.tfvars (gitignored)

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "skillmap"
}

variable "environment" {
  description = "Environment: dev, staging, prod"
  type        = string
  default     = "dev"
}

variable "postgres_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance size — db.t3.micro is free tier"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the database inside PostgreSQL"
  type        = string
  default     = "skillmapdb"
}

variable "db_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "skillmap"
}

variable "db_password" {
  description = "Master password for PostgreSQL"
  type        = string
  sensitive   = true   # Terraform won't print this in logs
}