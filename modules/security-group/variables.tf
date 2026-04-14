variable "name" {
  type = string
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
