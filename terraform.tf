terraform {
  required_version = ">= 1.0.0"

  # S3 Backend Configuration (Partial)
  #
  # NOTE: The S3 bucket is pre-created by ./bootstrap_account.sh using AWS CLI
  # Terraform does NOT manage the backend bucket - it only uses it for state storage
  # Backend bucket is created with versioning, encryption, and public access blocking
  #
  # This uses partial backend configuration. Actual values are provided via:
  #   - Local: terraform init -backend-config="bucket=..." -backend-config="key=..." -backend-config="region=..."
  #   - CI/CD: GitHub environment variables (TFSTATE_BUCKET, TFSTATE_KEY, TFSTATE_REGION)
  #   - Bootstrap: ./bootstrap_account.sh auto-runs terraform init with the correct flags
  #
  # Alternative: Use Terraform Cloud instead by replacing this with:
  #   cloud {
  #     organization = "YOUR_ORG"
  #     workspaces { name = "dbt-lambda" }
  #   }

  backend "s3" {}
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
