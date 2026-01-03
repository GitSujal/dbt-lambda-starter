terraform {
  required_version = ">= 1.0.0"

  # S3 Backend Configuration
  #
  # NOTE: The S3 bucket is pre-created by ./bootstrap_account.sh using AWS CLI
  # Terraform does NOT manage the backend bucket - it only uses it for state storage
  # Backend bucket is created with versioning, encryption, and public access blocking
  #
  # The bucket name and region are automatically updated by bootstrap_account.sh
  # To enable remote state after bootstrap:
  #   1. Run: terraform init -migrate-state
  #
  # Alternative: Use Terraform Cloud instead by replacing this with:
  #   cloud {
  #     organization = "YOUR_ORG"
  #     workspaces { name = "dbt-lambda" }
  #   }

  backend "s3" {
    bucket  = "dbt-lambda-terraform-state-180294223557"
    key     = "terraform.tfstate"
    region  = "ap-southeast-2"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}
