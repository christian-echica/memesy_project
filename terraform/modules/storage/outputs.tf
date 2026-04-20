output "media_bucket_id"        { value = aws_s3_bucket.media.id }
output "media_bucket_arn"       { value = aws_s3_bucket.media.arn }
output "media_bucket_domain"    { value = aws_s3_bucket.media.bucket_regional_domain_name }
output "frontend_bucket_id"     { value = aws_s3_bucket.frontend.id }
output "frontend_bucket_arn"    { value = aws_s3_bucket.frontend.arn }
output "frontend_bucket_domain" { value = aws_s3_bucket.frontend.bucket_regional_domain_name }
