output "replication_group_id" {
  value = aws_elasticache_replication_group.this.id
}

output "primary_endpoint_address" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "member_clusters" {
  value = tolist(aws_elasticache_replication_group.this.member_clusters)
}

output "node_count" {
  value = var.num_cache_clusters
}

output "url" {
  description = "Non-secret connection URL (TLS, no AUTH token; access is restricted by security group)."
  value       = "rediss://${aws_elasticache_replication_group.this.primary_endpoint_address}:6379/0?ssl_cert_reqs=required"
}
