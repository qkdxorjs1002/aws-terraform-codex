variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_role_name" {
  type    = string
  default = null

  validation {
    condition = (
      (var.node_role_arn != null && trimspace(var.node_role_arn) != "") ||
      (var.node_role_name != null && trimspace(var.node_role_name) != "")
    )
    error_message = "Either node_role_arn or node_role_name must be provided for the EKS node group."
  }
}

variable "node_role_arn" {
  type    = string
  default = null
}

variable "ami_type" {
  type    = string
  default = null
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "instance_types" {
  type    = list(string)
  default = []
}

variable "desired_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "disk_size" {
  type    = number
  default = null
}

variable "disk_encryption" {
  type    = bool
  default = true
}

variable "release_version" {
  type    = string
  default = null
}

variable "force_update_version" {
  type    = bool
  default = false
}

variable "launch_template" {
  type = object({
    name    = string
    version = string
  })
  default = null
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "taints" {
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string
  }))
  default = []
}

variable "update_config" {
  type = object({
    max_unavailable            = optional(number)
    max_unavailable_percentage = optional(number)
  })
  default = null
}

variable "remote_access" {
  type = object({
    enabled                = bool
    ec2_ssh_key            = optional(string)
    source_security_groups = optional(list(string))
  })
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
