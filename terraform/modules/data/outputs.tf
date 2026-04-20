output "db_endpoint"             { value = aws_db_instance.this.endpoint }
output "db_name"                 { value = aws_db_instance.this.db_name }
output "db_username"             { value = aws_db_instance.this.username }
output "db_password_ssm_arn"     { value = aws_ssm_parameter.db_password.arn }
output "redis_endpoint"          { value = aws_elasticache_replication_group.this.primary_endpoint_address }
output "redis_auth_token_ssm_arn" { value = aws_ssm_parameter.redis_auth_token.arn }
output "redis_port"              { value = aws_elasticache_replication_group.this.port }
