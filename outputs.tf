# Root-level outputs re-exported from the infrastructure module
# These provide the key information needed to use the dbt-on-Lambda starter

output "data_buckets" {
  description = "S3 buckets for dbt data pipeline (raw input, processed output)"
  value       = module.infrastructure.data_buckets
}

output "data_bucket_arns" {
  description = "ARNs of the dbt data pipeline S3 buckets"
  value       = module.infrastructure.data_bucket_arns
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = module.infrastructure.athena_results_bucket
}

output "glue_database_name" {
  description = "Glue catalog database name for dbt metadata"
  value       = module.infrastructure.glue_database_name
}

output "glue_database_arn" {
  description = "Glue catalog database ARN"
  value       = module.infrastructure.glue_database_arn
}

output "dbt_runner_arn" {
  description = "ARN of the dbt_runner Lambda function"
  value       = module.infrastructure.dbt_runner_arn
}

output "dbt_runner_name" {
  description = "Name of the dbt_runner Lambda function for invocation"
  value       = module.infrastructure.dbt_runner_name
}

output "deployment_summary" {
  description = "Summary of the dbt-on-Lambda starter deployment"
  value = {
    environment       = var.environment
    aws_region        = var.aws_region
    raw_bucket        = module.infrastructure.data_buckets.raw
    processed_bucket  = module.infrastructure.data_buckets.processed
    athena_results    = module.infrastructure.athena_results_bucket
    glue_database     = module.infrastructure.glue_database_name
    dbt_runner_lambda = module.infrastructure.dbt_runner_name
  }
}
