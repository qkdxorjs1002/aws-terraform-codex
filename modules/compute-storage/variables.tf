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

variable "security_group_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "iam_role_arns_by_name" {
  type    = map(string)
  default = {}
}

variable "iam_instance_profile_names_by_role_name" {
  type    = map(string)
  default = {}
}

variable "eks_cluster_attributes_by_name" {
  type    = map(any)
  default = {}
}

variable "acm_certificate_arns_by_domain_name" {
  type    = map(string)
  default = {}
}
