locals {
  name     = "${var.project}-${var.env}"
  tags     = merge(var.tags, { Module = "compute" })
  services = toset(["listing", "order", "payment"])
}

data "aws_region" "current" {}

# ── ECR Repositories ──────────────────────────────────────────────────────────

resource "aws_ecr_repository" "this" {
  for_each             = local.services
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }

  tags = merge(local.tags, { Name = "${local.name}-${each.key}" })
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = merge(local.tags, { Name = "${local.name}-cluster" })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "ecs" {
  for_each          = local.services
  name              = "/ecs/${local.name}/${each.key}"
  retention_in_days = 30
  tags              = local.tags
}

# ── Application Load Balancer ─────────────────────────────────────────────────

resource "aws_lb" "this" {
  name                       = "${local.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.sg_alb_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = true
  tags                       = merge(local.tags, { Name = "${local.name}-alb" })
}

resource "aws_lb_target_group" "this" {
  for_each    = local.services
  name        = "${var.project}-${each.key}-${var.env}"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = merge(local.tags, { Name = "${local.name}-tg-${each.key}" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # Default: listing service
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["listing"].arn
  }
}

resource "aws_lb_listener_rule" "order" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["order"].arn
  }
  condition {
    path_pattern { values = ["/api/orders*"] }
  }
}

resource "aws_lb_listener_rule" "payment" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["payment"].arn
  }
  condition {
    path_pattern { values = ["/api/payment*", "/api/webhook*"] }
  }
}

# ── ECS Task Definitions ──────────────────────────────────────────────────────

locals {
  common_env = [
    { name = "ENV",           value = var.env },
    { name = "DB_HOST",       value = split(":", var.db_endpoint)[0] },
    { name = "DB_PORT",       value = "5432" },
    { name = "DB_NAME",       value = var.db_name },
    { name = "DB_USER",       value = var.db_username },
    { name = "REDIS_HOST",    value = var.redis_endpoint },
    { name = "REDIS_PORT",    value = tostring(var.redis_port) },
    { name = "MEDIA_BUCKET",  value = var.media_bucket_id },
    { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
  ]
  common_secrets = [
    { name = "DB_PASSWORD",       valueFrom = var.db_password_ssm_arn },
    { name = "REDIS_AUTH_TOKEN",  valueFrom = var.redis_auth_token_ssm_arn },
  ]
  payment_extra_secrets = [
    { name = "STRIPE_SECRET_KEY", valueFrom = var.stripe_secret_key_ssm_arn },
  ]
}

resource "aws_ecs_task_definition" "this" {
  for_each                 = local.services
  family                   = "${local.name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${aws_ecr_repository.this[each.key].repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 5000
      protocol      = "tcp"
    }]
    environment = local.common_env
    secrets     = concat(local.common_secrets, each.key == "payment" ? local.payment_extra_secrets : [])
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs[each.key].name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = each.key
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = merge(local.tags, { Service = each.key })
}

# ── ECS Services ──────────────────────────────────────────────────────────────

resource "aws_ecs_service" "this" {
  for_each        = local.services
  name            = "${local.name}-${each.key}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_ecs_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this[each.key].arn
    container_name   = each.key
    container_port   = 5000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller { type = "ECS" }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = merge(local.tags, { Service = each.key })
}

# ── Application Auto Scaling ──────────────────────────────────────────────────

resource "aws_appautoscaling_target" "this" {
  for_each           = local.services
  max_capacity       = 10
  min_capacity       = var.desired_count
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each           = local.services
  name               = "${local.name}-${each.key}-cpu-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
