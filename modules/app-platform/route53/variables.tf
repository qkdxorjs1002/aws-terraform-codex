variable "resources_by_type" {
  type    = any
  default = {}
}

variable "vpc_ids_by_name" {
  type    = map(string)
  default = {}
}
