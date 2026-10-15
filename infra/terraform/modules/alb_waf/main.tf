locals {
  api_host            = "api.${var.domain}"
  admin_host          = "admin.${var.domain}"
  pay_host            = "pay.${var.domain}"
  has_admin_allowlist = length(var.admin_ip_allowlist) > 0
}

resource "aws_lb" "this" {
  name                       = "${var.name_prefix}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  idle_timeout               = var.idle_timeout_seconds
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
  enable_http2               = true

  dynamic "access_logs" {
    for_each = var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.name_prefix
      enabled = true
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })

  lifecycle {
    precondition {
      condition     = !var.require_admin_ip_allowlist || local.has_admin_allowlist
      error_message = "admin_ip_allowlist must not be empty in this environment (require_admin_ip_allowlist = true)."
    }
  }
}

# ------------------------------------------------------------------ target groups
resource "aws_lb_target_group" "api" {
  name_prefix          = "mcapi-"
  vpc_id               = var.vpc_id
  port                 = var.api_port
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-api" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "ws" {
  name_prefix = "mcws-"
  vpc_id      = var.vpc_id
  port        = var.ws_port
  protocol    = "HTTP"
  target_type = "ip"
  # Long drain so open chat sockets can finish or reconnect elsewhere during a rolling deploy.
  deregistration_delay = 120

  health_check {
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ws" })

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------ listeners
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Unknown host: same answer the application gives.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown host"
      status_code  = "400"
    }
  }
}

# WebSocket upgrade (wss://api.<domain>/ws/chat) goes to the ws service; ALB supports WebSockets natively.
resource "aws_lb_listener_rule" "ws" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ws.arn
  }
  condition {
    host_header {
      values = [local.api_host]
    }
  }
  condition {
    path_pattern {
      values = [var.ws_path_pattern]
    }
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
  condition {
    host_header {
      values = [local.api_host]
    }
  }
}

# admin. and pay. are served by the same api processes (Django host routing). The admin IP allowlist is
# enforced in WAF (below), which scales past the ALB's 5-values-per-rule limit.
resource "aws_lb_listener_rule" "admin" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
  condition {
    host_header {
      values = [local.admin_host]
    }
  }
}

resource "aws_lb_listener_rule" "pay" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
  condition {
    host_header {
      values = [local.pay_host]
    }
  }
}

# ------------------------------------------------------------------ WAF
resource "aws_wafv2_ip_set" "admin_allow" {
  count = local.has_admin_allowlist ? 1 : 0

  name               = "${var.name_prefix}-admin-allow"
  description        = "Operator IPs allowed to reach the admin host"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.admin_ip_allowlist
  tags               = var.tags
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.name_prefix}-web-acl"
  description = "Marriage Connect ALB protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # 0: admin host only from the allowlist (when configured).
  dynamic "rule" {
    for_each = local.has_admin_allowlist ? [1] : []
    content {
      name     = "admin-ip-allowlist"
      priority = 0

      action {
        block {}
      }

      statement {
        and_statement {
          statement {
            byte_match_statement {
              search_string         = local.admin_host
              positional_constraint = "STARTS_WITH"
              field_to_match {
                single_header {
                  name = "host"
                }
              }
              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
            }
          }
          statement {
            not_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.admin_allow[0].arn
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "${var.name_prefix}-admin-ip-allowlist"
      }
    }
  }

  # 1: stricter limit on the auth prefix.
  rule {
    name     = "rate-limit-auth"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_auth_rate_limit_per_5min
        aggregate_key_type = "IP"
        scope_down_statement {
          byte_match_statement {
            search_string         = var.auth_path_prefix
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${var.name_prefix}-rate-limit-auth"
    }
  }

  # 2: global per-IP rate limit.
  rule {
    name     = "rate-limit-global"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${var.name_prefix}-rate-limit-global"
    }
  }

  # 10+: AWS managed rule groups.
  dynamic "rule" {
    for_each = {
      "AWSManagedRulesAmazonIpReputationList" = 10
      "AWSManagedRulesCommonRuleSet"          = 11
      "AWSManagedRulesKnownBadInputsRuleSet"  = 12
      "AWSManagedRulesSQLiRuleSet"            = 13
    }
    content {
      name     = rule.key
      priority = rule.value

      override_action {
        dynamic "none" {
          for_each = var.waf_managed_rules_count_only ? [] : [1]
          content {}
        }
        dynamic "count" {
          for_each = var.waf_managed_rules_count_only ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "${var.name_prefix}-${rule.key}"
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${var.name_prefix}-web-acl"
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# WAF logs: the name must start with aws-waf-logs-. Credentials-bearing headers are redacted.
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = var.waf_log_retention_days
  tags              = var.tags
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "waf_logs" {
  statement {
    sid       = "AllowWafLogDelivery"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.waf.arn}:*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name     = "${var.name_prefix}-waf-logs"
  policy_document = data.aws_iam_policy_document.waf_logs.json
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_cloudwatch_log_resource_policy.waf]
}
