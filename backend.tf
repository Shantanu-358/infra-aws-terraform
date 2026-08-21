terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  backend "s3" {
    bucket       = "my-microservices-tfstate-bucket-2026"
    key          = "production/terraform.tfstate"
    region       = "ap-south-2"
    use_lockfile = true # Enables native S3 state locking (replaces dynamodb_table)
    encrypt      = true
  }
}