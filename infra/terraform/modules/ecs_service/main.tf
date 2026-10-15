locals {
  family       = "${var.name_prefix}-${var.name}"
  has_port     = var.container_port != null
  environment  = [for k, v in var.environment : { name = k, value = v }]
  secrets_list = [for k, arn in var.secrets : { name = k, valueFrom = arn }]

  # python is always present in the image; curl may not be. The Host header is needed because the
  # application rejects unknown hosts.
  health_check_cmd = [
    "CMD-SHELL",
    "python -c \"import urllib.request as u; r=u.Request('http://127.0.0.1:${coalesce(var.container_port, 0)}/ready', headers={'Host': '${var.health_check_host}'}); u.urlopen(r, timeout=4)\" || exit 1"
  ]

  port_extras = {
    for k, v in {
      portMappings = [{ containerPort = coalesce(var.container_port, 0), protocol = "tcp" }]
      healthCheck = {
        command     = local.health_check_cmd
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    } : k => v if local.has_port
  }

  container_definition = merge(
    {
      name        = var.name
      image       = var.image
      essential   = true
      command     = var.command
      environment = local.environment
      secrets     = local.secrets_list
      stopTimeout = var.stop_timeout_seconds
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = var.name
        }
      }
    },
    local.port_extras
  )
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/mc/${trimprefix(var.name_prefix, "mc-")}/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ------------------------------------------------------------------ IAM
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: pulls the image, writes logs, and reads ONLY this service's secrets at task start.
resource "aws_iam_role" "execution" {
  name               = "${local.family}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  statement {
    sid       = "ReadInjectedSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = values(var.secrets)
  }
  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "DecryptSecretsKey"
      actions   = ["kms:Decrypt"]
      resources = var.kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  count  = length(var.secrets) > 0 ? 1 : 0
  name   = "read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets[0].json
}

resource "aws_iam_role" "task" {
  name               = "${local.family}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "task" {
  count  = var.task_role_policy_json != null ? 1 : 0
  name   = "app-access"
  role   = aws_iam_role.task.id
  policy = var.task_role_policy_json
}

# ------------------------------------------------------------------ task definition
resource "aws_ecs_task_definition" "this" {
  family                   = local.family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([local.container_definition])
  tags                  = var.tags
}

# ------------------------------------------------------------------ service
resource "aws_ecs_service" "this" {
  count = var.create_service ? 1 : 0

  name            = local.family
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = var.min_healthy_percent
  deployment_maximum_percent         = var.max_percent
  health_check_grace_period_seconds  = var.target_group_arn != null ? var.health_check_grace_seconds : null
  enable_execute_command             = false
  propagate_tags                     = "SERVICE"

  # ECS rolls back automatically if new tasks never become healthy.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  tags = var.tags

  # CI (deploy-*.yml) registers new task definition revisions with the new image and updates the service.
  # Terraform must not move the service back to the revision it created. desired_count is owned by
  # autoscaling for api/ws.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_appautoscaling_target" "this" {
  count = var.create_service && var.enable_autoscaling ? 1 : 0

  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this[0].name}"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.create_service && var.enable_autoscaling ? 1 : 0

  name               = "${local.family}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  resource_id        = aws_appautoscaling_target.this[0].resource_id

  target_tracking_scaling_policy_configuration {
    target_value = var.autoscaling_cpu_target
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
