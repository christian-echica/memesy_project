variable "project"                   { type = string }
variable "env"                       { type = string }
variable "sqs_queue_name"            { type = string }
variable "lambda_role_arn"           { type = string }
variable "private_subnet_ids"        { type = list(string) }
variable "sg_lambda_id"              { type = string }
variable "media_bucket_arn"          { type = string }
variable "cloudfront_media_domain"   { type = string }
variable "ses_domain"                { type = string }
variable "ses_sender_email"          { type = string }
variable "lambda_package_s3_bucket"  { type = string }
variable "lambda_package_s3_key"     { type = string }

variable "dlq_alarm_sns_arn" {
  type        = string
  default     = ""
  description = "SNS topic ARN for DLQ depth alarm notifications. Leave empty to create alarm without an action."
}

variable "tags" {
  type    = map(string)
  default = {}
}
