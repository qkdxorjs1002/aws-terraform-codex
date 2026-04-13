variable "name" {
  type = string
}

variable "cidr" {
  type = string
}

variable "additional_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "instance_tenancy" {
  type    = string
  default = "default"
}

variable "assign_generated_ipv6_cidr_block" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
