variable "resources_by_type" {
  type    = any
  default = {}
}

variable "region" {
  type = string
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

variable "nat_gateway_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "internet_gateway_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "iam_role_arns_by_name" {
  type    = map(string)
  default = {}
}
