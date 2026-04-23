variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type = string
}

variable "revoke_rules_on_delete" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
