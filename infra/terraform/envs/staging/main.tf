data "aws_caller_identity" "current" {}

locals {
  name_prefix    = "mc-${var.environment}"
  secrets_prefix = "mc/${var.environment}"

  # Non-secret configuration only. Anything sensitive is a Secrets Manager entry (module.secrets) injected
  # through the ECS `secrets` block, never through `environment`.
  app_environment = merge(
    {
      DJANGO_SETTINGS_MODULE = "config.settings.${var.environment}"
      MC_DOMAIN              = var.domain
      AWS_REGION             = var.region
      MEDIA_BUCKET           = module.s3.media_private_bucket
      EXPORTS_BUCKET         = module.s3.exports_private_bucket
      MEDIA_SSE              = "aws:kms"
      REDIS_URL              = module.redis.url
      ADMIN_IP_ALLOWLIST     = join(",", var.admin_ip_allowlist)
      MC_TRUSTED_PROXY_COUNT = "1"
      LOG_LEVEL              = var.log_level
    },
    var.app_extra_environment
  )

  health_check_host = "api.${var.domain}"
  image             = "${aws_ecr_repository.backend.repository_url}:${var.image_tag}"
}

# Guard: secret names must never be passed as plain environment values.
resource "terraform_data" "no_secrets_in_environment" {
  lifecycle {
    precondition {
      condition     = length(setintersection(toset(keys(var.app_extra_environment)), var.secret_env_vars)) == 0
      error_message = "app_extra_environment contains a name that is managed as a secret. Secrets are injected via Secrets Manager only."
    }
  }
}

# ------------------------------------------------------------------ foundations
module "kms" {
  source               = "../../modules/kms"
  name_prefix          = local.name_prefix
  deletion_window_days = var.kms_deletion_window_days
}

module "network" {
  source             = "../../modules/network"
  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

module "secrets" {
  source               = "../../modules/secrets"
  name_prefix          = local.secrets_prefix
  kms_key_arn          = module.kms.data_key_arn
  secret_env_vars      = var.secret_env_vars
  recovery_window_days = var.secret_recovery_window_days
}

module "s3" {
  source                         = "../../modules/s3"
  name_prefix                    = local.name_prefix
  media_kms_key_arn              = module.kms.media_key_arn
  force_destroy                  = var.s3_force_destroy
  noncurrent_version_expiry_days = var.s3_noncurrent_version_expiry_days
  static_cors_origins            = var.static_cors_origins
}

module "rds" {
  source                       = "../../modules/rds"
  name_prefix                  = local.name_prefix
  subnet_ids                   = module.network.data_subnet_ids
  security_group_id            = module.network.db_security_group_id
  kms_key_arn                  = module.kms.data_key_arn
  instance_class               = var.db_instance_class
  allocated_storage_gb         = var.db_allocated_storage_gb
  max_allocated_storage_gb     = var.db_max_allocated_storage_gb
  multi_az                     = var.db_multi_az
  deletion_protection          = var.deletion_protection
  pitr_retention_days          = var.db_pitr_retention_days
  enable_aws_backup            = var.db_enable_aws_backup
  snapshot_retention_days      = var.db_snapshot_retention_days
  performance_insights_enabled = var.db_performance_insights
}

module "redis" {
  source                  = "../../modules/redis"
  name_prefix             = local.name_prefix
  subnet_ids              = module.network.data_subnet_ids
  security_group_id       = module.network.cache_security_group_id
  kms_key_arn             = module.kms.data_key_arn
  node_type               = var.redis_node_type
  num_cache_clusters      = var.redis_num_cache_clusters
  snapshot_retention_days = var.redis_snapshot_retention_days
}

module "alb_waf" {
  source                       = "../../modules/alb_waf"
  name_prefix                  = local.name_prefix
  vpc_id                       = module.network.vpc_id
  public_subnet_ids            = module.network.public_subnet_ids
  alb_security_group_id        = module.network.alb_security_group_id
  domain                       = var.domain
  certificate_arn              = var.certificate_arn
  deletion_protection          = var.deletion_protection
  admin_ip_allowlist           = var.admin_ip_allowlist
  require_admin_ip_allowlist   = var.require_admin_ip_allowlist
  waf_managed_rules_count_only = var.waf_managed_rules_count_only
  waf_rate_limit_per_5min      = var.waf_rate_limit_per_5min
  waf_auth_rate_limit_per_5min = var.waf_auth_rate_limit_per_5min
  health_check_matcher         = var.alb_health_check_matcher
}

# ------------------------------------------------------------------ container registry
resource "aws_ecr_repository" "backend" {
  name                 = "${local.name_prefix}-backend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = !var.deletion_protection

  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = module.kms.data_key_arn
  }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the most recent ${var.ecr_keep_images} images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = var.ecr_keep_images }
      action       = { type = "expire" }
    }]
  })
}

# ------------------------------------------------------------------ ECS
resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_iam_policy_document" "task_app" {
  statement {
    sid       = "ObjectAccessPrivateBuckets"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
    resources = ["${module.s3.media_private_arn}/*", "${module.s3.exports_private_arn}/*"]
  }
  statement {
    sid       = "ListPrivateBuckets"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [module.s3.media_private_arn, module.s3.exports_private_arn]
  }
  statement {
    sid       = "PublishStaticAssets"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.s3.static_public_arn}/*"]
  }
  statement {
    sid       = "UseDataAndMediaKeys"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [module.kms.data_key_arn, module.kms.media_key_arn]
  }
  statement {
    sid       = "TransactionalEmailAndModeration"
    actions   = ["ses:SendEmail", "ses:SendRawEmail", "rekognition:DetectModerationLabels"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "task_kms_only" {
  statement {
    sid       = "UseDataKeyForFieldEncryption"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [module.kms.data_key_arn]
  }
}

module "api" {
  source = "../../modules/ecs_service"

  # The target group must be attached to a listener rule before an ECS service can register with it.
  depends_on = [module.alb_waf]

  name_prefix  = local.name_prefix
  name         = "api"
  region       = var.region
  cluster_arn  = aws_ecs_cluster.this.arn
  cluster_name = aws_ecs_cluster.this.name

  image             = local.image
  command           = ["gunicorn", "config.asgi:application", "-k", "uvicorn.workers.UvicornWorker", "-b", "0.0.0.0:8000"]
  container_port    = 8000
  target_group_arn  = module.alb_waf.api_target_group_arn
  health_check_host = local.health_check_host

  cpu              = var.api_cpu
  memory           = var.api_memory
  cpu_architecture = var.cpu_architecture
  desired_count    = var.api_min_tasks

  enable_autoscaling = true
  min_capacity       = var.api_min_tasks
  max_capacity       = var.api_max_tasks

  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.app_security_group_id]
  environment        = local.app_environment
  secrets            = module.secrets.arns
  kms_key_arns       = [module.kms.data_key_arn]

  task_role_policy_json = data.aws_iam_policy_document.task_app.json
  log_retention_days    = var.log_retention_days
}

module "ws" {
  source = "../../modules/ecs_service"

  # The target group must be attached to a listener rule before an ECS service can register with it.
  depends_on = [module.alb_waf]

  name_prefix  = local.name_prefix
  name         = "ws"
  region       = var.region
  cluster_arn  = aws_ecs_cluster.this.arn
  cluster_name = aws_ecs_cluster.this.name

  image             = local.image
  command           = ["daphne", "-b", "0.0.0.0", "-p", "8001", "config.asgi:application"]
  container_port    = 8001
  target_group_arn  = module.alb_waf.ws_target_group_arn
  health_check_host = local.health_check_host

  cpu              = var.ws_cpu
  memory           = var.ws_memory
  cpu_architecture = var.cpu_architecture
  desired_count    = var.ws_min_tasks

  enable_autoscaling = true
  min_capacity       = var.ws_min_tasks
  max_capacity       = var.ws_max_tasks

  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.app_security_group_id]
  environment        = local.app_environment
  secrets            = module.secrets.arns
  kms_key_arns       = [module.kms.data_key_arn]

  task_role_policy_json = data.aws_iam_policy_document.task_kms_only.json
  stop_timeout_seconds  = 60
  log_retention_days    = var.log_retention_days
}

module "worker" {
  source = "../../modules/ecs_service"

  name_prefix  = local.name_prefix
  name         = "worker"
  region       = var.region
  cluster_arn  = aws_ecs_cluster.this.arn
  cluster_name = aws_ecs_cluster.this.name

  image            = local.image
  command          = ["celery", "-A", "config", "worker", "-Q", "default,media,billing,notify", "--loglevel=INFO"]
  cpu              = var.worker_cpu
  memory           = var.worker_memory
  cpu_architecture = var.cpu_architecture
  desired_count    = var.worker_count

  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.app_security_group_id]
  environment        = local.app_environment
  secrets            = module.secrets.arns
  kms_key_arns       = [module.kms.data_key_arn]

  task_role_policy_json = data.aws_iam_policy_document.task_app.json
  stop_timeout_seconds  = 120
  log_retention_days    = var.log_retention_days
}

# Exactly one beat scheduler: never run two (duplicate scheduled jobs). min healthy 0 / max 100 makes ECS
# stop the old task before starting the new one during a deploy.
module "beat" {
  source = "../../modules/ecs_service"

  name_prefix  = local.name_prefix
  name         = "beat"
  region       = var.region
  cluster_arn  = aws_ecs_cluster.this.arn
  cluster_name = aws_ecs_cluster.this.name

  image            = local.image
  command          = ["celery", "-A", "config", "beat", "--loglevel=INFO"]
  cpu              = 256
  memory           = 512
  cpu_architecture = var.cpu_architecture
  desired_count    = 1

  min_healthy_percent = 0
  max_percent         = 100

  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.app_security_group_id]
  environment        = local.app_environment
  secrets            = module.secrets.arns
  kms_key_arns       = [module.kms.data_key_arn]

  task_role_policy_json = data.aws_iam_policy_document.task_kms_only.json
  log_retention_days    = var.log_retention_days
}

# One-off migration task: task definition only, no service. Run by the deploy workflows through
# infra/scripts/ecs-run-migrate.sh BEFORE the services are updated.
module "migrate" {
  source = "../../modules/ecs_service"

  name_prefix    = local.name_prefix
  name           = "migrate"
  region         = var.region
  cluster_arn    = aws_ecs_cluster.this.arn
  cluster_name   = aws_ecs_cluster.this.name
  create_service = false

  image            = local.image
  command          = ["python", "manage.py", "migrate", "--noinput"]
  cpu              = 512
  memory           = 1024
  cpu_architecture = var.cpu_architecture

  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.app_security_group_id]
  environment        = local.app_environment
  secrets            = module.secrets.arns
  kms_key_arns       = [module.kms.data_key_arn]

  task_role_policy_json = data.aws_iam_policy_document.task_kms_only.json
  log_retention_days    = var.log_retention_days
}

# ------------------------------------------------------------------ monitoring
module "observability" {
  source = "../../modules/observability"

  name_prefix    = local.name_prefix
  alb_arn_suffix = module.alb_waf.alb_arn_suffix
  target_group_arn_suffixes = {
    api = module.alb_waf.api_target_group_arn_suffix
    ws  = module.alb_waf.ws_target_group_arn_suffix
  }

  rds_identifier                = module.rds.identifier
  rds_max_connections_threshold = var.db_max_connections_alarm

  redis_member_cluster_ids = module.redis.member_clusters
  redis_node_count         = module.redis.node_count

  ecs_cluster_name = aws_ecs_cluster.this.name
  ecs_services = {
    api    = { service_name = module.api.service_name, min_running = var.api_min_tasks }
    ws     = { service_name = module.ws.service_name, min_running = var.ws_min_tasks }
    worker = { service_name = module.worker.service_name, min_running = 1 }
    beat   = { service_name = module.beat.service_name, min_running = 1 }
  }

  log_groups = {
    api    = module.api.log_group_name
    ws     = module.ws.log_group_name
    worker = module.worker.log_group_name
    beat   = module.beat.log_group_name
  }

  alert_emails = var.alert_emails
}
