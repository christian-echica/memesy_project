provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# ── Resolve account + region for computed ARNs (breaks circular deps) ─────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Computed ahead of module calls so both iam and compute get the ARN
  # without depending on the events module output.
  sqs_queue_name = "${var.project}-${var.env}-purchase-events"
  sqs_queue_arn  = "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${local.sqs_queue_name}"
  sqs_queue_url  = "https://sqs.${data.aws_region.current.name}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${local.sqs_queue_name}"
}

# ── 1. Networking ─────────────────────────────────────────────────────────────

module "networking" {
  source               = "../../modules/networking"
  project              = var.project
  env                  = var.env
  azs                  = var.azs
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

# ── 2. Storage ────────────────────────────────────────────────────────────────

module "storage" {
  source     = "../../modules/storage"
  project    = var.project
  env        = var.env
  account_id = var.account_id
  tags       = var.tags
}

# ── 3. IAM ────────────────────────────────────────────────────────────────────

module "iam" {
  source                 = "../../modules/iam"
  project                = var.project
  env                    = var.env
  media_bucket_arn       = module.storage.media_bucket_arn
  sqs_queue_arn          = local.sqs_queue_arn
  db_password_ssm_arn    = module.data.db_password_ssm_arn
  github_org             = var.github_org
  github_repo            = var.github_repo
  lambda_package_bucket  = var.lambda_package_s3_bucket
  create_oidc_provider   = var.create_oidc_provider
  tags                   = var.tags
}

# ── 4. Data (RDS + Redis) ─────────────────────────────────────────────────────

module "data" {
  source             = "../../modules/data"
  project            = var.project
  env                = var.env
  private_subnet_ids = module.networking.private_subnet_ids
  sg_rds_id          = module.networking.sg_rds_id
  sg_redis_id        = module.networking.sg_redis_id
  db_instance_class  = var.db_instance_class
  redis_node_type    = var.redis_node_type
  tags               = var.tags
}

# ── 5. Compute (ECS + ALB + ECR) ─────────────────────────────────────────────

module "compute" {
  source                = "../../modules/compute"
  project               = var.project
  env                   = var.env
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  sg_alb_id             = module.networking.sg_alb_id
  sg_ecs_id             = module.networking.sg_ecs_id
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn     = module.iam.ecs_task_role_arn
  db_endpoint           = module.data.db_endpoint
  db_name               = module.data.db_name
  db_username           = module.data.db_username
  db_password_ssm_arn   = module.data.db_password_ssm_arn
  redis_endpoint        = module.data.redis_endpoint
  redis_port            = module.data.redis_port
  media_bucket_id       = module.storage.media_bucket_id
  sqs_queue_url         = local.sqs_queue_url
  cpu                   = var.ecs_cpu
  memory                = var.ecs_memory
  desired_count         = var.ecs_desired_count
  tags                  = var.tags
}

# ── 6. CDN (CloudFront + WAF) ─────────────────────────────────────────────────

module "cdn" {
  source                    = "../../modules/cdn"
  project                   = var.project
  env                       = var.env
  frontend_bucket_domain    = module.storage.frontend_bucket_domain
  frontend_bucket_id        = module.storage.frontend_bucket_id
  media_bucket_domain       = module.storage.media_bucket_domain
  media_bucket_id           = module.storage.media_bucket_id
  alb_dns_name              = module.compute.alb_dns_name
  cloudfront_public_key_pem = var.cloudfront_public_key_pem
  tags                      = var.tags
}

# ── 7. Events (SQS + Lambda + SES) ───────────────────────────────────────────

module "events" {
  source                   = "../../modules/events"
  project                  = var.project
  env                      = var.env
  sqs_queue_name           = local.sqs_queue_name
  lambda_role_arn          = module.iam.lambda_role_arn
  private_subnet_ids       = module.networking.private_subnet_ids
  sg_lambda_id             = module.networking.sg_lambda_id
  media_bucket_arn         = module.storage.media_bucket_arn
  cloudfront_media_domain  = module.cdn.media_distribution_domain
  ses_domain               = var.ses_domain
  ses_sender_email         = var.ses_sender_email
  lambda_package_s3_bucket = var.lambda_package_s3_bucket
  lambda_package_s3_key    = var.lambda_package_s3_key
  tags                     = var.tags
}
