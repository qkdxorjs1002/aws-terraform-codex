variable "cluster_name" {
  type = string
}

variable "addon_name" {
  type = string
}

variable "addon_version" {
  type    = string
  default = "latest"
}

variable "resolve_conflicts_on_create" {
  type    = string
  default = "OVERWRITE"
}

variable "resolve_conflicts_on_update" {
  type    = string
  default = "PRESERVE"
}

variable "service_account_role_arn" {
  type    = string
  default = null
}

variable "configuration_values" {
  type    = string
  default = null
}

variable "preserve" {
  type    = bool
  default = false
}
