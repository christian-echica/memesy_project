variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "memesy"
}

variable "env" {
  type    = string
  default = "prod"
}

variable "account_id" {
  type        = string
  description = "AWS account ID — used to guarantee globally unique S3 bucket names"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ── Data Layer ────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
}

# ── Compute ───────────────────────────────────────────────────────────────────

variable "ecs_desired_count" {
  type    = number
  default = 2
}

variable "ecs_cpu" {
  type    = number
  default = 512
}

variable "ecs_memory" {
  type    = number
  default = 1024
}


# ── Events & Messaging ────────────────────────────────────────────────────────

variable "ses_domain" {
  type    = string
  default = "christianechica.com"
}

variable "ses_sender_email" {
  type    = string
  default = "noreply@christianechica.com"
}

variable "lambda_package_s3_bucket" {
  type        = string
  description = "S3 bucket containing the Lambda deployment package (pre-populated by CI/CD)"
}

variable "lambda_package_s3_key" {
  type        = string
  description = "S3 key for the Lambda deployment package zip"
  default     = "purchase-handler/latest.zip"
}

# ── GitHub Actions OIDC ──────────────────────────────────────────────────────

variable "github_org" {
  type        = string
  description = "GitHub organisation that owns the Memesy repo (e.g. 'acme-org')"
}

variable "github_repo" {
  type        = string
  default     = "memesy"
  description = "GitHub repository name used to scope the OIDC trust policy"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set false if a GitHub Actions OIDC provider already exists in this AWS account"
}

# ── CDN ───────────────────────────────────────────────────────────────────────

variable "cloudfront_public_key_pem" {
  type        = string
  sensitive   = true
  description = "RSA-2048 public key PEM for CloudFront signed URLs. Store the private key in Secrets Manager."
}

# ── Tagging ───────────────────────────────────────────────────────────────────

variable "tags" {
  type = map(string)
  default = {
    Project     = "memesy"
    Environment = "prod"
    ManagedBy   = "terraform"
    Owner       = "platform"
    CostCenter  = "eng"
  }
}
