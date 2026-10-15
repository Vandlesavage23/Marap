output "arns" {
  description = "Map of environment variable name to secret ARN (for ECS `secrets`)."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
}

output "all_arns" {
  value = [for s in aws_secretsmanager_secret.this : s.arn]
}
