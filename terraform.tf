terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket       = "dbt-lambda-terraform-state-180294223557" # Replace with your unique bucket name as this cannot be a variable
    key          = "terraform.tfstate"
    region       = "ap-southeast-2" # Replace with your desired region as this cannot be a variable
    encrypt      = true
    use_lockfile = true
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
