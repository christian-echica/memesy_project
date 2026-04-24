variable "project"                  { type = string }
variable "env"                      { type = string }
variable "frontend_bucket_domain"   { type = string }
variable "frontend_bucket_id"       { type = string }
variable "media_bucket_domain"      { type = string }
variable "media_bucket_id"          { type = string }
variable "alb_dns_name"             { type = string }

variable "app_domain" {
  type        = string
  default     = ""
  description = "Custom domain for the frontend CloudFront distribution (e.g. app.christianechica.com). Leave empty to use the default CloudFront domain."
}

variable "route53_zone_id" {
  type        = string
  default     = ""
  description = "Route 53 hosted zone ID for app_domain. Required when app_domain is set."
}

variable "cloudfront_public_key_pem" {
  type      = string
  sensitive = true
  description = "RSA public key PEM for CloudFront signed URLs. Private key stored in Secrets Manager."
}

variable "tags" {
  type    = map(string)
  default = {}
}
