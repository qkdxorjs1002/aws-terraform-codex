variable "resources_by_type" {
  type    = any
  default = {}
}

variable "iam_role_arns_by_name" {
  type    = map(string)
  default = {}
}

variable "auto_scaling_group_names_by_key" {
  type    = map(string)
  default = {}
}

variable "alb_target_group_names_by_key" {
  type    = map(string)
  default = {}
}
