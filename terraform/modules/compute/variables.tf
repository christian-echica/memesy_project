variable "project"                { type = string }
variable "env"                    { type = string }
variable "vpc_id"                 { type = string }
variable "public_subnet_ids"      { type = list(string) }
variable "private_subnet_ids"     { type = list(string) }
variable "sg_alb_id"              { type = string }
variable "sg_ecs_id"              { type = string }
variable "ecs_execution_role_arn" { type = string }
variable "ecs_task_role_arn"      { type = string }
variable "db_endpoint"            { type = string }
variable "db_name"                { type = string }
variable "db_username"            { type = string }
variable "db_password_ssm_arn"    { type = string }
variable "redis_endpoint"              { type = string }
variable "redis_port"                 { type = number }
variable "redis_auth_token_ssm_arn"   { type = string }
variable "stripe_secret_key_ssm_arn"     { type = string }
variable "stripe_webhook_secret_ssm_arn" { type = string }
variable "media_bucket_id"        { type = string }
variable "sqs_queue_url"          { type = string }

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
