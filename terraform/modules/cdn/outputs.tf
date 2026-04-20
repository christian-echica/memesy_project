output "frontend_distribution_id"     { value = aws_cloudfront_distribution.frontend.id }
output "frontend_distribution_domain" { value = aws_cloudfront_distribution.frontend.domain_name }
output "media_distribution_id"        { value = aws_cloudfront_distribution.media.id }
output "media_distribution_domain"    { value = aws_cloudfront_distribution.media.domain_name }
output "media_key_group_id"           { value = aws_cloudfront_key_group.media.id }
output "waf_web_acl_arn"              { value = aws_wafv2_web_acl.this.arn }
