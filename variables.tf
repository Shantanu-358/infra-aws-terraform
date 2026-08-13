variable "aws_region" {
  description = "The primary AWS Region to deploy all infrastructure into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, production)"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name for the Amazon EKS cluster"
  type        = string
  default     = "microservices-eks"
}

variable "db_password" {
  description = "Master password for the PostgreSQL RDS Database"
  type        = string
  sensitive   = true # Prevents Terraform from printing this password in CLI logs
  default     = "SecurePassword2026!"
}