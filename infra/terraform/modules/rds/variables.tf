variable "name_prefix" {
  type = string
}

variable "subnet_ids" {
  description = "Data subnets for the DB subnet group."
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "kms_key_arn" {
  description = "mc-data KMS key ARN (storage, managed master secret, Performance Insights, backup vault)."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL major version (Bible: 16)."
  type        = string
  default     = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling."
  type        = number
  default     = 100
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "pitr_retention_days" {
  description = "RDS automated backup retention = point-in-time-recovery window (Bible: 7 in prod)."
  type        = number
  default     = 1
}

variable "enable_aws_backup" {
  description = "Daily AWS Backup snapshot plan with snapshot_retention_days retention (Bible: 35 in prod)."
  type        = bool
  default     = false
}

variable "snapshot_retention_days" {
  type    = number
  default = 35
}

variable "backup_window" {
  description = "Daily automated backup window (UTC)."
  type        = string
  default     = "01:00-02:00"
}

variable "maintenance_window" {
  type    = string
  default = "sun:02:30-sun:03:30"
}

variable "apply_immediately" {
  type    = bool
  default = false
}

variable "performance_insights_enabled" {
  type    = bool
  default = true
}

variable "log_min_duration_statement_ms" {
  description = "Log statements slower than this (ms). Statement text may contain data: keep logs access-restricted."
  type        = number
  default     = 1000
}

variable "tags" {
  type    = map(string)
  default = {}
}
