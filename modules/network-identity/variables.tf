variable "resources_by_type" {
  type    = any
  default = {}
}

variable "vpc_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "subnet_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "route_table_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "security_group_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "cloudfront_distribution_arns_by_name" {
  type    = map(string)
  default = {}
}
