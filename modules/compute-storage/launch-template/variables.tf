variable "resources_by_type" {
  type    = any
  default = {}
}

variable "security_group_ids_by_name" {
  type    = map(string)
  default = {}
}
