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

variable "alb_dns_names_by_name" {
  type    = map(string)
  default = {}
}

variable "s3_bucket_regional_domain_names_by_name" {
  type    = map(string)
  default = {}
}

variable "acm_certificate_arns_by_domain_name" {
  type    = map(string)
  default = {}
}
