# bootstrap/main.tf
#
# This is a SEPARATE, tiny Terraform project from the main one. It exists
# only to create the S3 bucket + DynamoDB table that the MAIN project will
# then use to store ITS state remotely. It's a one-time chicken-and-egg
# solve: you can't configure Terraform to store state in an S3 bucket that
# doesn't exist yet. This config keeps its own (local) state file, which is
# fine — you'll basically never touch this again after today.

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
  }
}

provider "aws" {
  region = "us-east-1"
}

# S3 bucket names are GLOBALLY unique across all of AWS, not just your
# account — so we append a random suffix to avoid collisions with every
# other person doing this exact tutorial.
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "portfolio-tf-state-${random_id.suffix.hex}"

  # Prevents `terraform destroy` from ever accidentally deleting this bucket
  # — it holds the state for everything else you've built.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
  # Versioning means every state write is kept as a history, not
  # overwritten in place — if a bad apply corrupts state, you can roll back
  # to a previous version of the file.
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table used purely for STATE LOCKING: when someone runs
# `terraform apply`, Terraform writes a lock record here first. If a second
# apply starts concurrently (e.g. you locally AND a GitHub Actions run at
# the same time), it sees the lock and refuses to proceed — preventing two
# processes from corrupting the same state file simultaneously.
resource "aws_dynamodb_table" "tf_lock" {
  name         = "portfolio-tf-lock"
  billing_mode = "PAY_PER_REQUEST" # no capacity planning needed at this scale
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  value = aws_dynamodb_table.tf_lock.name
}
