resource "aws_secretsmanager_secret" "this" {
  for_each = var.secret_env_vars

  name                    = "${var.name_prefix}/${each.key}"
  description             = "Value for environment variable ${each.key}; set out of band, never in Terraform."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_days
  tags                    = merge(var.tags, { EnvVar = each.key })
}
