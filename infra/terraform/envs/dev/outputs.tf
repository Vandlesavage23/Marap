output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_names" {
  value = {
    api    = module.api.service_name
    ws     = module.ws.service_name
    worker = module.worker.service_name
    beat   = module.beat.service_name
  }
}

output "migrate_task_family" {
  value = module.migrate.family
}

output "github_deploy_role_arn" {
  description = "Set as the AWS_DEPLOY_ROLE_ARN variable of the matching GitHub environment."
  value       = aws_iam_role.github_deploy.arn
}

output "alb_dns_name" {
  description = "Point api./admin./pay.<domain> at this (CNAME or alias)."
  value       = module.alb_waf.alb_dns_name
}

output "alb_zone_id" {
  value = module.alb_waf.alb_zone_id
}

output "hosts" {
  value = module.alb_waf.hosts
}

output "rds_identifier" {
  value = module.rds.identifier
}

output "rds_address" {
  value = module.rds.address
}

output "rds_master_user_secret_arn" {
  description = "RDS-managed secret holding the master username/password. Used by infra/scripts/compose-database-url.sh."
  value       = module.rds.master_user_secret_arn
}

output "secret_arns" {
  description = "Secrets Manager entries to populate out of band (ENV_VAR => ARN). ARNs are not secret."
  value       = module.secrets.arns
}

output "media_private_bucket" {
  value = module.s3.media_private_bucket
}

output "exports_private_bucket" {
  value = module.s3.exports_private_bucket
}

output "static_public_bucket" {
  value = module.s3.static_public_bucket
}

output "kms_data_key_arn" {
  value = module.kms.data_key_arn
}

output "kms_media_key_arn" {
  value = module.kms.media_key_arn
}

output "alerts_sns_topic_arn" {
  value = module.observability.sns_topic_arn
}
