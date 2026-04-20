output "frontend_url" {
  value       = "https://${module.cdn.frontend_distribution_domain}"
  description = "React SPA URL served via CloudFront"
}

output "media_cdn_domain" {
  value       = module.cdn.media_distribution_domain
  description = "CloudFront domain for buyer-scoped signed asset URLs"
}

output "alb_dns_name" {
  value       = module.compute.alb_dns_name
  description = "ALB DNS name (point your API subdomain CNAME here)"
}

output "db_endpoint" {
  value       = module.data.db_endpoint
  sensitive   = true
  description = "RDS PostgreSQL endpoint"
}

output "redis_endpoint" {
  value       = module.data.redis_endpoint
  sensitive   = true
  description = "ElastiCache Redis primary endpoint"
}

output "ecr_urls" {
  value       = module.compute.ecr_urls
  description = "ECR repository URLs per service: listing, order, payment"
}

output "ses_dkim_tokens" {
  value       = module.events.ses_dkim_tokens
  description = "Add these as CNAME records in DNS to verify SES domain"
}

output "waf_web_acl_arn" {
  value       = module.cdn.waf_web_acl_arn
  description = "WAF Web ACL ARN attached to CloudFront"
}

output "github_actions_role_arn" {
  value       = module.iam.github_actions_role_arn
  description = "IAM role ARN for GitHub Actions OIDC — set as GHA_ROLE_ARN repository secret"
}
