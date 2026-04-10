variable "name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_groups" {
  type    = list(string)
  default = []
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "authentication_mode" {
  type    = string
  default = null
}

variable "service_ipv4_cidr" {
  type    = string
  default = null
}

variable "ip_family" {
  type    = string
  default = null
}

variable "cluster_logging_enabled_types" {
  type    = list(string)
  default = []
}

variable "cluster_log_retention_days" {
  type    = number
  default = 30
}

variable "encryption_enabled" {
  type    = bool
  default = false
}

variable "encryption_resources" {
  type    = list(string)
  default = ["secrets"]
}

variable "encryption_kms_key_arn" {
  type    = string
  default = null
}

variable "cluster_role_name" {
  type    = string
  default = null

  validation {
    condition = (
      (var.cluster_role_arn != null && trimspace(var.cluster_role_arn) != "") ||
      (var.cluster_role_name != null && trimspace(var.cluster_role_name) != "")
    )
    error_message = "Either cluster_role_arn or cluster_role_name must be provided for the EKS cluster."
  }
}

variable "cluster_role_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
