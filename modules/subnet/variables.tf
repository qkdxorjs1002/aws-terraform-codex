variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "availability_zone" {
  type    = string
  default = null
}

variable "map_public_ip_on_launch" {
  type    = bool
  default = false
}

variable "assign_ipv6_address_on_creation" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
