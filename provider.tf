provider "aws" {
  region = var.aws_region
  # Note: AWS profile is not used in provider to support both local and CI/CD environments
  # - Locally: Users configure credentials via aws configure or AWS_PROFILE env var
  # - CI/CD: Credentials provided via GitHub OIDC (environment variables)

  default_tags {
    tags = var.default_tags
  }
}
