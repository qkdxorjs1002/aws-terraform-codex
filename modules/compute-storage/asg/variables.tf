variable "resources_by_type" {
  type    = any
  default = {}
}

variable "subnet_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "launch_template_names_by_key" {
  type    = map(string)
  default = {}
}

variable "launch_template_latest_versions_by_key" {
  type    = map(string)
  default = {}
}

variable "alb_target_group_arns_by_key" {
  type    = map(string)
  default = {}
}
