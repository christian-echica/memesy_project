variable "project"             { type = string }
variable "env"                 { type = string }
variable "media_bucket_arn"    { type = string }
variable "sqs_queue_arn"       { type = string }
variable "db_password_ssm_arn"       { type = string }
variable "redis_auth_token_ssm_arn"  { type = string }
variable "stripe_secret_key_ssm_arn"     { type = string }
variable "stripe_webhook_secret_ssm_arn" { type = string }

variable "github_org" {
  type        = string
  description = "GitHub organisation name (e.g. 'acme-org'). Used to scope the OIDC trust policy."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g. 'memesy'). Used to scope the OIDC trust policy to repo:org/repo:ref:refs/heads/main."
}

variable "lambda_package_bucket" {
  type        = string
  description = "S3 bucket name where GitHub Actions uploads Lambda deployment packages."
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set false if the GitHub Actions OIDC provider already exists in the account."
}

variable "tags" {
  type    = map(string)
  default = {}
}
