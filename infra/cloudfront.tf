# CloudFront distribution for serving dbt docs from private S3 bucket

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "dbt_docs" {
  name                              = "${var.bucket_prefix}-dbt-docs-oac"
  description                       = "OAC for dbt docs S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "dbt_docs" {
  comment             = "${var.bucket_prefix} dbt documentation"
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.dbt_docs.bucket_regional_domain_name
    origin_id                = "dbt-docs-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.dbt_docs.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "dbt-docs-s3"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # dbt docs is SPA-like; OAC returns 403 for missing objects
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    {
      Name    = "${var.bucket_prefix}-dbt-docs-cdn"
      Purpose = "dbt-Docs-Distribution"
    },
    var.extra_tags
  )
}
