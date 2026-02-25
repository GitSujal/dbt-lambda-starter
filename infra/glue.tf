# Glue Catalog Database
resource "aws_glue_catalog_database" "dbt_data_platform" {
  name = "${var.environment}-dbt-lambda-dataplatform"

  tags = merge(
    {
      Name = "${var.environment}-dbt-lambda-dataplatform"
      Type = "Glue-Database"
    },
    var.extra_tags
  )
}

# Athena Query Results Bucket
resource "aws_s3_bucket" "athena_results" {
  bucket        = lower("${var.bucket_prefix}-athena-results-${data.aws_caller_identity.current.account_id}")
  force_destroy = true

  tags = merge(
    {
      Name    = lower("${var.bucket_prefix}-athena-results")
      Type    = "Query-Results-Bucket"
      Purpose = "Athena-Query-Results"
    },
    var.extra_tags
  )
}

resource "aws_s3_bucket_versioning" "athena_results_versioning" {
  bucket = aws_s3_bucket.athena_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results_lifecycle" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "delete-athena-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results_encryption" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results_access" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}
