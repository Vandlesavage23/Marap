# Generated sizing for the staging environment; edit values here or override in terraform.tfvars.
# Nothing in this file is secret.

variable "region" {
  description = "AWS region. af-south-1 is the default; PENDING OD-04 (data residency decision)."
  type        = string
  default     = "af-south-1"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "domain" {
  description = "Base domain, e.g. dev.marriageconnect.example. Hosts: api./admin./pay.<domain>."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN (same region) covering api./admin./pay.<domain>."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as ORG/REPO."
  type        = string
}

variable "admin_ip_allowlist" {
  description = "IPv4 CIDRs allowed to reach admin.<domain> (WAF) and passed to the app as ADMIN_IP_ALLOWLIST."
  type        = list(string)
  default     = []
}

variable "image_tag" {
  description = "Image tag baked into Terraform-managed task definitions. CI deploys real tags; the services ignore this after creation."
  type        = string
  default     = "bootstrap"
}

variable "cpu_architecture" {
  description = "Must match how the image is built in CI (the workflows build linux/amd64)."
  type        = string
  default     = "X86_64"
}

variable "secret_env_vars" {
  description = "Environment variable names backed by Secrets Manager entries (values are set out of band)."
  type        = set(string)
  default = [
    "DJANGO_SECRET_KEY",
    "DATABASE_URL",
    "MC_DATA_KEYS_JSON",
    "MC_PEPPERS_JSON",
    "MC_JWT_PRIVATE_KEY_PEM",
    "MC_JWT_PUBLIC_KEY_PEM",
    "SENTRY_DSN",
    "AT_API_KEY",
    "SMILE_ID_API_KEY",
    "FLUTTERWAVE_SECRET_KEY",
    "FLUTTERWAVE_WEBHOOK_HASH",
    "FCM_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON",
    "APPLE_ROOT_CERTS_PEM_JSON",
  ]
}

variable "app_extra_environment" {
  description = <<-EOT
    Extra NON-SECRET environment values (provider class paths such as SMS_PROVIDER, IDENTITY_PROVIDER,
    PAYMENT_GATEWAY, STAFF_SSO_PROVIDER, APPLE_ENVIRONMENT, GOOGLE_PACKAGE_NAME, CLAMD_HOST ...).
    Names listed in secret_env_vars are rejected. staging/prod settings REQUIRE the real provider paths.
  EOT
  type        = map(string)
  default     = {}
}

variable "static_cors_origins" {
  type    = list(string)
  default = []
}

variable "alb_health_check_matcher" {
  description = "ALB health check success codes. See modules/alb_waf (Host header caveat)."
  type        = string
  default     = "200,400"
}

variable "alert_emails" {
  description = "Optional e-mail subscribers for the alerts SNS topic (must confirm)."
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Availability zones to span."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheap) instead of one per AZ."
  type        = bool
  default     = true
}

variable "kms_deletion_window_days" {
  description = "KMS key deletion waiting period."
  type        = number
  default     = 14
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window (0 = immediate delete, dev only)."
  type        = number
  default     = 7
}

variable "s3_force_destroy" {
  description = "Allow destroy of non-empty buckets."
  type        = bool
  default     = false
}

variable "s3_noncurrent_version_expiry_days" {
  description = "Days to keep noncurrent object versions in private buckets."
  type        = number
  default     = 14
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.medium"
}

variable "db_allocated_storage_gb" {
  description = "RDS initial storage (GiB)."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage_gb" {
  description = "RDS storage autoscaling ceiling (GiB)."
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "RDS Multi-AZ standby."
  type        = bool
  default     = false
}

variable "db_pitr_retention_days" {
  description = "Automated backup retention = PITR window."
  type        = number
  default     = 7
}

variable "db_enable_aws_backup" {
  description = "Daily AWS Backup snapshots."
  type        = bool
  default     = true
}

variable "db_snapshot_retention_days" {
  description = "AWS Backup snapshot retention."
  type        = number
  default     = 14
}

variable "db_performance_insights" {
  description = "RDS Performance Insights."
  type        = bool
  default     = true
}

variable "db_max_connections_alarm" {
  description = "Connections alarm threshold (about 80% of max_connections for the class)."
  type        = number
  default     = 150
}

variable "deletion_protection" {
  description = "Deletion protection on RDS and ALB; final snapshot on destroy; ECR not force-deleted."
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.small"
}

variable "redis_num_cache_clusters" {
  description = "Redis nodes (2+ = replica with automatic failover)."
  type        = number
  default     = 1
}

variable "redis_snapshot_retention_days" {
  description = "Redis snapshot retention (0 = none)."
  type        = number
  default     = 1
}

variable "require_admin_ip_allowlist" {
  description = "Fail plan if admin_ip_allowlist is empty."
  type        = bool
  default     = true
}

variable "waf_managed_rules_count_only" {
  description = "Run AWS managed WAF groups in Count mode (tuning) instead of Block."
  type        = bool
  default     = false
}

variable "waf_rate_limit_per_5min" {
  description = "WAF per-IP request limit per 5 minutes."
  type        = number
  default     = 3000
}

variable "waf_auth_rate_limit_per_5min" {
  description = "WAF per-IP limit per 5 minutes on the auth path prefix."
  type        = number
  default     = 100
}

variable "ecr_keep_images" {
  description = "Images kept by the ECR lifecycle policy."
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Application LOG_LEVEL."
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention for application logs."
  type        = number
  default     = 30
}

variable "api_cpu" {
  description = "api task CPU units."
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "api task memory MiB."
  type        = number
  default     = 1024
}

variable "api_min_tasks" {
  description = "api minimum (and initial) tasks."
  type        = number
  default     = 1
}

variable "api_max_tasks" {
  description = "api autoscaling maximum."
  type        = number
  default     = 3
}

variable "ws_cpu" {
  description = "ws task CPU units."
  type        = number
  default     = 512
}

variable "ws_memory" {
  description = "ws task memory MiB."
  type        = number
  default     = 1024
}

variable "ws_min_tasks" {
  description = "ws minimum (and initial) tasks."
  type        = number
  default     = 1
}

variable "ws_max_tasks" {
  description = "ws autoscaling maximum."
  type        = number
  default     = 3
}

variable "worker_cpu" {
  description = "worker task CPU units."
  type        = number
  default     = 512
}

variable "worker_memory" {
  description = "worker task memory MiB."
  type        = number
  default     = 1024
}

variable "worker_count" {
  description = "worker tasks."
  type        = number
  default     = 1
}

variable "create_github_oidc_provider" {
  description = "Create the account-wide GitHub OIDC provider. Only ONE environment per AWS account may set true; others look it up."
  type        = bool
  default     = false
}

variable "github_oidc_subject_suffixes" {
  description = "OIDC `sub` claim suffixes allowed to assume the deploy role (after repo:<github_repository>:)."
  type        = list(string)
  default     = ["ref:refs/tags/rc-*"]
}

variable "vpc_cidr" {
  description = "VPC CIDR (distinct per environment)."
  type        = string
  default     = "10.30.0.0/16"
}
