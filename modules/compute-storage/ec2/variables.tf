variable "resources_by_type" {
  type    = any
  default = {}
}

variable "subnet_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "security_group_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "iam_instance_profile_names_by_role_name" {
  type    = map(string)
  default = {}
}
