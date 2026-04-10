variable "name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "connection_type" {
  type    = string
  default = "public"
}

variable "allocation_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
