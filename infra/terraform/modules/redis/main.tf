resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

# Redis is both the Channels layer and the Celery broker: evicting keys would drop queued jobs, so the
# policy is noeviction (writes fail loudly and the Redis alarms fire instead).
resource "aws_elasticache_parameter_group" "this" {
  name        = "${var.name_prefix}-redis7"
  family      = "redis7"
  description = "${var.name_prefix} Redis 7 (broker + channel layer)"

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }

  tags = var.tags

}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "${var.name_prefix} Redis (Channels layer + Celery broker)"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.this.name

  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.num_cache_clusters > 1
  multi_az_enabled           = var.num_cache_clusters > 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.security_group_id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true

  snapshot_retention_limit   = var.snapshot_retention_days
  snapshot_window            = var.snapshot_retention_days > 0 ? "02:00-03:00" : null
  maintenance_window         = "sun:03:30-sun:04:30"
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-redis" })
}
