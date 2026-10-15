variable "name_prefix" {
  description = "Prefix for resource names, e.g. mc-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to span (2 or 3)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheap, dev) instead of one per AZ (prod)."
  type        = bool
  default     = true
}

variable "container_port_api" {
  description = "Container port of the api service (ALB to tasks)."
  type        = number
  default     = 8000
}

variable "container_port_ws" {
  description = "Container port of the ws service (ALB to tasks)."
  type        = number
  default     = 8001
}

variable "tags" {
  type    = map(string)
  default = {}
}
