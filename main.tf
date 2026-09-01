# main.tf
# This file configures WHICH cloud provider Terraform talks to, and which
# version of the AWS provider plugin to use. Pinning versions here matters:
# without it, `terraform init` could pull a newer provider release later that
# changes behavior underneath you.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # State is now stored remotely in S3 (with DynamoDB locking) instead of
  # locally, so both you and GitHub Actions can read/write the same state
  # safely. These values come from the bootstrap project's outputs.
  backend "s3" {
    bucket         = "portfolio-tf-state-2d9d4e48"
    key            = "portfolio/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "portfolio-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-portfolio-project"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
