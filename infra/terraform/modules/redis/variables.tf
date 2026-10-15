variable "name_prefix" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "num_cache_clusters" {
  description = "Nodes in the replication group (1 = no failover; 2+ = primary + replicas with Multi-AZ failover)."
  type        = number
  default     = 1
}

variable "engine_version" {
  type    = string
  default = "7.1"
}

variable "snapshot_retention_days" {
  type    = number
  default = 0
}

variable "apply_immediately" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
