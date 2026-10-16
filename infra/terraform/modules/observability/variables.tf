variable "name_prefix" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffixes" {
  description = "Map of logical name (api, ws) to target group ARN suffix. Keys must be static."
  type        = map(string)
}

variable "rds_identifier" {
  type = string
}

variable "rds_free_storage_threshold_bytes" {
  type    = number
  default = 5368709120 # 5 GiB
}

variable "rds_cpu_threshold_percent" {
  type    = number
  default = 80
}

variable "rds_max_connections_threshold" {
  description = "Alarm when DatabaseConnections exceeds this. Set from the instance class max_connections (~80%)."
  type        = number
  default     = 150
}

variable "redis_member_cluster_ids" {
  description = "ElastiCache member cluster ids (one alarm set each)."
  type        = list(string)
}

variable "redis_node_count" {
  description = "Static node count (must equal length(redis_member_cluster_ids)); used for count so plan does not depend on apply-time values."
  type        = number
}

variable "redis_memory_threshold_percent" {
  type    = number
  default = 80
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_services" {
  description = "Map of logical name to { service_name, min_running }. Keys must be static. Needs Container Insights on the cluster."
  type = map(object({
    service_name = string
    min_running  = number
  }))
}

variable "log_groups" {
  description = "Map of logical name to CloudWatch log group name carrying the application JSON logs. Keys must be static."
  type        = map(string)
}

variable "alert_names" {
  description = "Values of the structured log field `alert` that become alarms."
  type        = set(string)
  default = [
    "s1_report",
    "payments_reconciliation_mismatch",
    "admin_access_denied",
    "queue_age_high",
    "payment_webhook_failures",
    "otp_send_spike",
  ]
}

variable "alb_5xx_percent_threshold" {
  description = "Target 5xx as percent of requests (Bible 15: 2% for 5 min)."
  type        = number
  default     = 2
}

variable "alb_p95_response_seconds_threshold" {
  description = "p95 target response time in seconds (Bible 15: 1 s for 10 min)."
  type        = number
  default     = 1
}

variable "alb_elb_5xx_count_threshold" {
  description = "ELB-generated 5xx (no healthy target, WAF/ALB errors) per 5 minutes."
  type        = number
  default     = 10
}

variable "alert_emails" {
  description = "Optional e-mail subscribers to the alert topic (each must confirm the subscription). Prefer on-call tooling subscribed outside Terraform."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
