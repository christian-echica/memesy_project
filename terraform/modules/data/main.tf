locals {
  name = "${var.project}-${var.env}"
  tags = merge(var.tags, { Module = "data" })
}

# ── RDS PostgreSQL ────────────────────────────────────────────────────────────

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project}/${var.env}/db/password"
  type        = "SecureString"
  value       = random_password.db.result
  description = "RDS master password"
  tags        = local.tags
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = merge(local.tags, { Name = "${local.name}-db-subnet" })
}

resource "aws_db_parameter_group" "this" {
  name   = "${local.name}-pg15"
  family = "postgres15"
  tags   = local.tags
}

resource "aws_db_instance" "this" {
  identifier                = "${local.name}-postgres"
  engine                    = "postgres"
  engine_version            = "15"
  instance_class            = var.db_instance_class
  allocated_storage         = 20
  max_allocated_storage     = 200
  storage_type              = "gp3"
  storage_encrypted         = true
  db_name                   = var.db_name
  username                  = var.db_username
  password                  = random_password.db.result
  db_subnet_group_name      = aws_db_subnet_group.this.name
  parameter_group_name      = aws_db_parameter_group.this.name
  vpc_security_group_ids    = [var.sg_rds_id]
  multi_az                  = true
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-postgres-final"
  deletion_protection       = true
  performance_insights_enabled = true
  tags = merge(local.tags, { Name = "${local.name}-postgres" })
}

# ── ElastiCache Redis ─────────────────────────────────────────────────────────

resource "random_password" "redis_auth" {
  length  = 32
  special = false # Redis AUTH token must be alphanumeric
}

resource "aws_ssm_parameter" "redis_auth_token" {
  name        = "/${var.project}/${var.env}/redis/auth-token"
  type        = "SecureString"
  value       = random_password.redis_auth.result
  description = "ElastiCache Redis AUTH token"
  tags        = local.tags
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${local.name}-redis-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = local.tags
}

resource "aws_elasticache_parameter_group" "this" {
  name   = "${local.name}-redis7"
  family = "redis7"
  tags   = local.tags
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "${local.name}-redis"
  description                = "Session store, listing cache, Celery broker"
  node_type                  = var.redis_node_type
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  engine_version             = "7.1"
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.this.name
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.sg_redis_id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result
  snapshot_retention_limit   = 3
  maintenance_window         = "tue:05:00-tue:06:00"
  tags                       = merge(local.tags, { Name = "${local.name}-redis" })
}
