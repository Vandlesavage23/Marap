variable "name_prefix" {
  description = "Bucket name prefix, e.g. mc-dev. The AWS account id is appended for global uniqueness."
  type        = string
}

variable "media_kms_key_arn" {
  description = "mc-media KMS key ARN (SSE-KMS for private buckets)."
  type        = string
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets (dev only)."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiry_days" {
  description = "Days before noncurrent object versions are deleted in private buckets."
  type        = number
  default     = 30
}

variable "exports_expiry_days" {
  description = "Data export objects expire after this many days (Bible 10.9: link valid 7 days; extra margin for retries)."
  type        = number
  default     = 14
}

variable "static_cors_origins" {
  description = "Origins allowed to GET static-public assets from browsers (web checkout pages)."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
