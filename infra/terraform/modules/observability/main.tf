locals {
  namespace = "MarriageConnect/${var.name_prefix}"

  alert_filters = {
    for p in setproduct(keys(var.log_groups), tolist(var.alert_names)) :
    "${p[0]}-${p[1]}" => { group = p[0], alert = p[1] }
  }

  redis_nodes   = range(var.redis_node_count)
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ------------------------------------------------------------------ notification topic
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# ------------------------------------------------------------------ ALB
resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_percent" {
  alarm_name          = "${var.name_prefix}-alb-target-5xx-percent"
  alarm_description   = "Target 5xx responses above ${var.alb_5xx_percent_threshold}% of requests for 5 minutes."
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alb_5xx_percent_threshold
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  metric_query {
    id          = "pct"
    expression  = "IF(req > 0, 100 * err / req, 0)"
    label       = "5xx percent"
    return_data = true
  }
  metric_query {
    id = "err"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }
  metric_query {
    id = "req"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }

  tags = var.tags
}

# p95 target response time above the threshold for 10 consecutive 1-minute periods (Bible 15).
resource "aws_cloudwatch_metric_alarm" "alb_p95_latency" {
  alarm_name          = "${var.name_prefix}-alb-p95-target-response-time"
  alarm_description   = "p95 target response time above ${var.alb_p95_response_seconds_threshold}s for 10 minutes. See docs/runbooks/outage.md."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 10
  datapoints_to_alarm = 10
  threshold           = var.alb_p95_response_seconds_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_elb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-elb-5xx"
  alarm_description   = "ALB-generated 5xx responses (no healthy targets, gateway errors)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alb_elb_5xx_count_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "tg_unhealthy" {
  for_each = var.target_group_arn_suffixes

  alarm_name          = "${var.name_prefix}-tg-${each.key}-unhealthy-hosts"
  alarm_description   = "At least one ${each.key} target is failing health checks."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = each.value }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "tg_no_healthy" {
  for_each = var.target_group_arn_suffixes

  alarm_name          = "${var.name_prefix}-tg-${each.key}-no-healthy-hosts"
  alarm_description   = "No healthy ${each.key} targets: outage."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = each.value }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

# ------------------------------------------------------------------ RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name_prefix}-rds-cpu"
  alarm_description   = "RDS CPU above ${var.rds_cpu_threshold_percent}% for 15 minutes (Bible 15)."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.rds_cpu_threshold_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.name_prefix}-rds-free-storage"
  alarm_description   = "RDS free storage low."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.rds_free_storage_threshold_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.name_prefix}-rds-connections"
  alarm_description   = "RDS connection count high."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.rds_max_connections_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

# ------------------------------------------------------------------ Redis (per node)
resource "aws_cloudwatch_metric_alarm" "redis_engine_cpu" {
  count = var.redis_node_count

  alarm_name          = "${var.name_prefix}-redis-${count.index}-engine-cpu"
  alarm_description   = "Redis engine CPU high (single-threaded: saturates early)."
  namespace           = "AWS/ElastiCache"
  metric_name         = "EngineCPUUtilization"
  dimensions          = { CacheClusterId = var.redis_member_cluster_ids[count.index] }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  count = var.redis_node_count

  alarm_name          = "${var.name_prefix}-redis-${count.index}-memory"
  alarm_description   = "Redis memory use high; policy is noeviction so a full node rejects writes (queued jobs, chat fan-out)."
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  dimensions          = { CacheClusterId = var.redis_member_cluster_ids[count.index] }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.redis_memory_threshold_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  count = var.redis_node_count

  alarm_name          = "${var.name_prefix}-redis-${count.index}-evictions"
  alarm_description   = "Redis evicted keys; broker data may be lost. Should be zero with noeviction."
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  dimensions          = { CacheClusterId = var.redis_member_cluster_ids[count.index] }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

# ------------------------------------------------------------------ ECS running task count
resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks" {
  for_each = var.ecs_services

  alarm_name          = "${var.name_prefix}-ecs-${each.key}-running-tasks"
  alarm_description   = "Fewer than ${each.value.min_running} ${each.key} tasks running (requires Container Insights)."
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = each.value.service_name }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = each.value.min_running
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = var.tags
}

# ------------------------------------------------------------------ structured-log alerts
# The application writes JSON log lines such as {"level":"WARNING","alert":"s1_report",...}. One metric
# filter per (log group, alert) all feed the same metric, which one alarm watches.
resource "aws_cloudwatch_log_metric_filter" "alert" {
  for_each = local.alert_filters

  name           = "${var.name_prefix}-alert-${each.value.alert}-${each.value.group}"
  log_group_name = var.log_groups[each.value.group]
  pattern        = "{ $.alert = \"${each.value.alert}\" }"

  metric_transformation {
    name          = "alert_${each.value.alert}"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "alert" {
  for_each = var.alert_names

  alarm_name          = "${var.name_prefix}-alert-${each.key}"
  alarm_description   = "Structured log alert ${each.key} was emitted. See the matching runbook in docs/runbooks/."
  namespace           = local.namespace
  metric_name         = "alert_${each.key}"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  tags                = var.tags

  depends_on = [aws_cloudwatch_log_metric_filter.alert]
}
