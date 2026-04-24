locals {
  name = "${var.project}-${var.env}"
  tags = merge(var.tags, { Module = "cdn" })
}

# ── ACM Certificate for custom domain ────────────────────────────────────────

resource "aws_acm_certificate" "frontend" {
  count             = var.app_domain != "" ? 1 : 0
  domain_name       = var.app_domain
  validation_method = "DNS"
  tags              = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.app_domain != "" ? {
    for dvo in aws_acm_certificate.frontend[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "frontend" {
  count                   = var.app_domain != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "app" {
  count   = var.app_domain != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.app_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

# ── WAF Web ACL (CLOUDFRONT scope must be us-east-1) ─────────────────────────

resource "aws_wafv2_web_acl" "this" {
  name        = "${local.name}-waf"
  description = "Managed rule groups protecting Memesy CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "CommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "IpReputationList"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-IpReputation"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

# ── Origin Access Controls ────────────────────────────────────────────────────

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "media" {
  name                              = "${local.name}-media-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── CloudFront Key Pair for Signed URLs ───────────────────────────────────────
# Generate: openssl genrsa -out cf_private.pem 2048
#           openssl rsa -pubout -in cf_private.pem -out cf_public.pem
# Store private key in Secrets Manager: memesy/prod/cf-signing-private-key

resource "aws_cloudfront_public_key" "media" {
  name        = "${local.name}-media-sigkey"
  comment     = "Used by Lambda to generate buyer-scoped signed URLs"
  encoded_key = var.cloudfront_public_key_pem
}

resource "aws_cloudfront_key_group" "media" {
  name    = "${local.name}-media-keygroup"
  comment = "Key group for media signed URL enforcement"
  items   = [aws_cloudfront_public_key.media.id]
}

# ── CloudFront: Frontend SPA ──────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.this.arn
  price_class         = "PriceClass_100"
  aliases             = var.app_domain != "" ? [var.app_domain] : []

  # S3 origin: React static files
  origin {
    domain_name              = var.frontend_bucket_domain
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # ALB origin: Flask API
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "api-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API routes → ALB (no cache)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "api-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Origin", "Accept", "Content-Type"]
      cookies { forward = "all" }
    }
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Default → S3 (SPA with long TTL for hashed assets)
  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # React SPA: serve index.html on S3 403/404
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.app_domain == "" ? true : null
    acm_certificate_arn            = var.app_domain != "" ? aws_acm_certificate_validation.frontend[0].certificate_arn : null
    ssl_support_method             = var.app_domain != "" ? "sni-only" : null
    minimum_protocol_version       = var.app_domain != "" ? "TLSv1.2_2021" : null
  }

  tags = merge(local.tags, { Name = "${local.name}-cf-frontend" })
}

# ── CloudFront: Media Assets (buyer-scoped signed URLs) ──────────────────────

resource "aws_cloudfront_distribution" "media" {
  enabled         = true
  is_ipv6_enabled = true
  web_acl_id      = aws_wafv2_web_acl.this.arn
  price_class     = "PriceClass_100"

  origin {
    domain_name              = var.media_bucket_domain
    origin_id                = "media-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.media.id
  }

  default_cache_behavior {
    target_origin_id       = "media-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    trusted_key_groups     = [aws_cloudfront_key_group.media.id]
    forwarded_values {
      query_string = true # required for signed URL params
      cookies { forward = "none" }
    }
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 604800
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(local.tags, { Name = "${local.name}-cf-media" })
}

# ── S3 Bucket Policies (allow CloudFront OAC) ─────────────────────────────────

data "aws_iam_policy_document" "frontend_oac" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.frontend_bucket_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id
  policy = data.aws_iam_policy_document.frontend_oac.json
}

data "aws_iam_policy_document" "media_oac" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.media_bucket_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.media.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "media" {
  bucket = var.media_bucket_id
  policy = data.aws_iam_policy_document.media_oac.json
}
