variable "name_prefix" {
  description = "e.g. mc-dev"
  type        = string
}

variable "name" {
  description = "Service / task family suffix: api, ws, worker, beat, migrate."
  type        = string
}

variable "region" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "create_service" {
  description = "false = only the task definition, roles and log group (one-off tasks such as migrate)."
  type        = bool
  default     = true
}

variable "image" {
  description = "Full image reference incl. tag, e.g. <acct>.dkr.ecr.<region>.amazonaws.com/mc-backend:bootstrap. CI replaces the tag on deploy."
  type        = string
}

variable "command" {
  description = "Container command (the image's CMD is the api command)."
  type        = list(string)
}

variable "container_port" {
  description = "Port exposed to the ALB. null for worker/beat/migrate."
  type        = number
  default     = null
}

variable "target_group_arn" {
  description = "ALB target group ARN (api/ws only)."
  type        = string
  default     = null
}

variable "health_check_host" {
  description = "Host header the container health check sends (Django host routing rejects unknown hosts). Only used when container_port is set."
  type        = string
  default     = ""
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "cpu_architecture" {
  type    = string
  default = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "enable_autoscaling" {
  type    = bool
  default = false
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 4
}

variable "autoscaling_cpu_target" {
  type    = number
  default = 60
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "environment" {
  description = "Plain, NON-secret environment values only. Secrets go in `secrets`."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of environment variable name to Secrets Manager ARN (ECS `secrets`, injected at task start)."
  type        = map(string)
  default     = {}
}

variable "kms_key_arns" {
  description = "KMS keys the execution role must decrypt (the key encrypting the secrets)."
  type        = list(string)
  default     = []
}

variable "task_role_policy_json" {
  description = "Optional IAM policy document (JSON) for the task role (S3, KMS data-key use, ...)."
  type        = string
  default     = null
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "min_healthy_percent" {
  type    = number
  default = 100
}

variable "max_percent" {
  type    = number
  default = 200
}

variable "health_check_grace_seconds" {
  type    = number
  default = 60
}

variable "stop_timeout_seconds" {
  description = "Seconds ECS waits after SIGTERM before SIGKILL (max 120 on Fargate)."
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
