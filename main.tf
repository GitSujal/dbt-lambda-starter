module "infrastructure" {
  source        = "./infra"
  aws_region    = var.aws_region
  aws_profile   = var.aws_profile
  environment   = var.environment
  bucket_prefix = var.bucket_prefix
  default_tags  = var.default_tags
  extra_tags    = var.extra_tags
}

