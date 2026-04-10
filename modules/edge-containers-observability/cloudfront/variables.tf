variable "resources_by_type" {
  type    = any
  default = {}
}

variable "waf_web_acl_arns_by_name" {
  type    = map(string)
  default = {}
}
