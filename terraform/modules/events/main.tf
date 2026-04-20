locals {
  name = "${var.project}-${var.env}"
  tags = merge(var.tags, { Module = "events" })
}

# ── SQS Dead Letter Queue ─────────────────────────────────────────────────────

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.sqs_queue_name}-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"
  tags                      = merge(local.tags, { Name = "${var.sqs_queue_name}-dlq" })
}

# ── SQS Purchase Events Queue ─────────────────────────────────────────────────

resource "aws_sqs_queue" "purchase" {
  name                       = var.sqs_queue_name
  visibility_timeout_seconds = 300 # matches Lambda timeout
  message_retention_seconds  = 86400
  kms_master_key_id          = "alias/aws/sqs"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
  tags = merge(local.tags, { Name = var.sqs_queue_name })
}

# ── Lambda: Purchase Handler ──────────────────────────────────────────────────
# Triggered by SQS. Generates CloudFront signed URLs and emails buyer via SES.

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name}-purchase-handler"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_lambda_function" "purchase_handler" {
  function_name = "${local.name}-purchase-handler"
  description   = "Generates CloudFront signed URLs and emails buyer after successful payment"
  role          = var.lambda_role_arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = 60
  memory_size   = 256

  s3_bucket = var.lambda_package_s3_bucket
  s3_key    = var.lambda_package_s3_key

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  environment {
    variables = {
      PROJECT          = var.project
      ENV              = var.env
      SES_SENDER_EMAIL = var.ses_sender_email
      CF_MEDIA_DOMAIN  = var.cloudfront_media_domain
      SSM_PREFIX       = "/${var.project}/${var.env}"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = merge(local.tags, { Name = "${local.name}-purchase-handler" })
}

# ── SQS → Lambda Event Source Mapping ────────────────────────────────────────

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = aws_sqs_queue.purchase.arn
  function_name                      = aws_lambda_function.purchase_handler.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
  function_response_types            = ["ReportBatchItemFailures"]
}

# ── SES Domain Identity ───────────────────────────────────────────────────────
# After apply, add the DKIM CNAME records from ses_dkim_tokens to your DNS.

resource "aws_ses_domain_identity" "this" {
  domain = var.ses_domain
}

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

# ── DLQ Depth Alarm ───────────────────────────────────────────────────────────
# Any message landing in the DLQ means Lambda failed 3 consecutive attempts —
# alert immediately so no purchase event is silently lost.

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${local.name}-dlq-messages-visible"
  alarm_description   = "Purchase event stuck in DLQ — manual intervention required"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.dlq_alarm_sns_arn != "" ? [var.dlq_alarm_sns_arn] : []
  tags                = local.tags
}
