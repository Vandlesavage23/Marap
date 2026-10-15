variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "domain" {
  description = "Base domain. Hosts are api.<domain>, admin.<domain>, pay.<domain> (Bible 2.2)."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate in the same region covering api./admin./pay.<domain> (created and validated outside this module)."
  type        = string
}

variable "ssl_policy" {
  type    = string
  default = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "api_port" {
  type    = number
  default = 8000
}

variable "ws_port" {
  type    = number
  default = 8001
}

variable "ws_path_pattern" {
  description = "Path (on the api host) routed to the ws service."
  type        = string
  default     = "/ws/*"
}

variable "health_check_path" {
  type    = string
  default = "/ready"
}

variable "health_check_matcher" {
  description = <<-EOT
    HTTP codes counted as healthy by the ALB target group health check. The backend serves /ready and /health
    for any Host header (probe paths only), so the default is a strict 200.
  EOT
  type        = string
  default     = "200"
}

variable "idle_timeout_seconds" {
  description = "ALB idle timeout; long enough for WebSocket connections that rely on app-level pings."
  type        = number
  default     = 3600
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "access_logs_bucket" {
  description = "Optional S3 bucket for ALB access logs (bucket policy managed outside this module). Empty = disabled."
  type        = string
  default     = ""
}

variable "admin_ip_allowlist" {
  description = "IPv4 CIDRs allowed to reach admin.<domain>. Enforced in WAF. Empty = no restriction (dev only)."
  type        = list(string)
  default     = []
}

variable "require_admin_ip_allowlist" {
  description = "Fail the plan if admin_ip_allowlist is empty (set true in staging/prod)."
  type        = bool
  default     = false
}

variable "waf_managed_rules_count_only" {
  description = "Run AWS managed rule groups in Count mode (tuning). false = Block."
  type        = bool
  default     = false
}

variable "waf_rate_limit_per_5min" {
  description = "Requests per IP per 5 minutes over all paths before blocking."
  type        = number
  default     = 2000
}

variable "waf_auth_rate_limit_per_5min" {
  description = "Requests per IP per 5 minutes to the auth path prefix before blocking (OTP abuse / SMS pumping)."
  type        = number
  default     = 100
}

variable "auth_path_prefix" {
  type    = string
  default = "/api/v1/auth"
}

variable "waf_log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
