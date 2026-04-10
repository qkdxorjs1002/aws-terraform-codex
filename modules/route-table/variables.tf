variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "associated_subnet_ids" {
  type    = list(string)
  default = []
}

variable "routes" {
  type = list(object({
    destination_type  = string
    destination_value = string
    target_type       = string
    target_id         = string
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
