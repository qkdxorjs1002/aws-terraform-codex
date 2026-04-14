variable "resources_by_type" {
  type    = any
  default = {}
}

variable "security_group_ids_by_name" {
  type    = map(string)
  default = {}
}

variable "eks_cluster_attributes_by_name" {
  type    = map(any)
  default = {}
}
