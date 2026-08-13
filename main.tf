# Configures the AWS provider to interact with your AWS account
provider "aws" {
  region = var.aws_region # Pulls region value from variables.tf

  # Global tags automatically applied to every resource created in AWS
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "MicroservicesApp"
      ManagedBy   = "Terraform"
    }
  }
}