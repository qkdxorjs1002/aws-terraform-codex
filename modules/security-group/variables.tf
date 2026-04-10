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

variable "inbound_rules" {
  type = list(object({
    description = optional(string)
    protocol    = string
    from_port   = number
    to_port     = number
    peer_type   = string
    peer_value  = string
  }))
  default = []
}

variable "outbound_rules" {
  type = list(object({
    description = optional(string)
    protocol    = string
    from_port   = number
    to_port     = number
    peer_type   = string
    peer_value  = string
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
