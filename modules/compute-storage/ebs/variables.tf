variable "resources_by_type" {
  type    = any
  default = {}
}

variable "ec2_instance_ids_by_name" {
  type    = map(string)
  default = {}
}
