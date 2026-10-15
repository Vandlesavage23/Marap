output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "api_target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "api_target_group_arn_suffix" {
  value = aws_lb_target_group.api.arn_suffix
}

output "ws_target_group_arn" {
  value = aws_lb_target_group.ws.arn
}

output "ws_target_group_arn_suffix" {
  value = aws_lb_target_group.ws.arn_suffix
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}

output "hosts" {
  value = {
    api   = local.api_host
    admin = local.admin_host
    pay   = local.pay_host
  }
}
