output "sqs_purchase_queue_arn" { value = aws_sqs_queue.purchase.arn }
output "sqs_purchase_queue_url" { value = aws_sqs_queue.purchase.url }
output "sqs_dlq_arn"            { value = aws_sqs_queue.dlq.arn }
output "lambda_function_arn"    { value = aws_lambda_function.purchase_handler.arn }
output "ses_dkim_tokens"        { value = aws_ses_domain_dkim.this.dkim_tokens }
