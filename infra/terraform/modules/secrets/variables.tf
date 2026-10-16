variable "name_prefix" {
  description = "Secret path prefix, e.g. mc/dev. Secret names are <name_prefix>/<ENV_VAR>."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key (mc-data) used to encrypt the secrets."
  type        = string
}

variable "secret_env_vars" {
  description = <<-EOT
    Environment variable names that the application reads from Secrets Manager. One (empty) secret is
    created per name. VALUES ARE NEVER SET HERE: an operator writes them out of band
    (aws secretsmanager put-secret-value) and the ECS agent injects them at task start.
  EOT
  type        = set(string)
  default = [
    "DJANGO_SECRET_KEY",
    "DATABASE_URL",
    "MC_DATA_KEYS_JSON",
    "MC_PEPPERS_JSON",
    "MC_JWT_PRIVATE_KEY_PEM",
    "MC_JWT_PUBLIC_KEY_PEM",
    "SENTRY_DSN",
    "METRICS_TOKEN",
    "AT_API_KEY",
    "SMILE_ID_API_KEY",
    "FLUTTERWAVE_SECRET_KEY",
    "FLUTTERWAVE_WEBHOOK_HASH",
    "FCM_SERVICE_ACCOUNT_JSON",
    "GOOGLE_SERVICE_ACCOUNT_JSON",
    "APPLE_ROOT_CERTS_PEM_JSON",
  ]
}

variable "recovery_window_days" {
  description = "Deletion recovery window. 0 = delete immediately (dev only)."
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
