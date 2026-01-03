# Remote State Backend Resources
#
# This file creates the resources needed for the S3 Remote Backend.
# To use these resources, uncomment the backend block in terraform.tf and run:
#   terraform init -migrate-state
#
# Note: These resources must be created BEFORE enabling the backend configuration.
# They are created in the default AWS account/region, separate from the main infrastructure.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "dbt-lambda-terraform-state-${data.aws_caller_identity.current.account_id}"

  # Prevent accidental deletion of this bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    {
      Name    = "dbt-lambda-terraform-state"
      Type    = "Terraform-State"
      Purpose = "Infrastructure-State-Storage"
    },
    var.extra_tags
  )
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_crypto" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_access" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "terraform_state_policy" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

