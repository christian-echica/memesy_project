variable "project"                  { type = string }
variable "env"                      { type = string }
variable "frontend_bucket_domain"   { type = string }
variable "frontend_bucket_id"       { type = string }
variable "media_bucket_domain"      { type = string }
variable "media_bucket_id"          { type = string }
variable "alb_dns_name"             { type = string }

variable "cloudfront_public_key_pem" {
  type      = string
  sensitive = true
  description = "RSA public key PEM for CloudFront signed URLs. Private key stored in Secrets Manager."
}

variable "tags" {
  type    = map(string)
  default = {}
}
