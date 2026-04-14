locals {
  use_role_lookup = var.node_role_name != null && trimspace(var.node_role_name) != ""
}

data "aws_iam_role" "node" {
  count = local.use_role_lookup ? 1 : 0
  name  = var.node_role_name
}

locals {
  effective_node_role_arn = local.use_role_lookup ? data.aws_iam_role.node[0].arn : var.node_role_arn

  launch_template_version_raw = var.launch_template == null ? null : trimspace(var.launch_template.version)
  launch_template_use_latest  = var.launch_template != null && lower(local.launch_template_version_raw) == "$latest"
  launch_template_use_default = var.launch_template != null && lower(local.launch_template_version_raw) == "$default"
  launch_template_use_lookup  = local.launch_template_use_latest || local.launch_template_use_default
}

data "aws_launch_template" "selected" {
  count = local.launch_template_use_lookup ? 1 : 0
  name  = var.launch_template.name
}

locals {
  effective_launch_template_version = var.launch_template == null ? null : (
    local.launch_template_use_latest ? tostring(data.aws_launch_template.selected[0].latest_version) :
    local.launch_template_use_default ? tostring(data.aws_launch_template.selected[0].default_version) :
    var.launch_template.version
  )
}

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.name
  node_role_arn   = local.effective_node_role_arn
  subnet_ids      = var.subnet_ids

  ami_type             = var.ami_type
  capacity_type        = var.capacity_type
  instance_types       = length(var.instance_types) > 0 ? var.instance_types : null
  release_version      = var.release_version
  force_update_version = var.force_update_version

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  disk_size = var.launch_template == null ? var.disk_size : null

  dynamic "launch_template" {
    for_each = var.launch_template == null ? [] : [var.launch_template]

    content {
      name    = launch_template.value.name
      version = local.effective_launch_template_version
    }
  }

  labels = var.labels

  dynamic "taint" {
    for_each = var.taints

    content {
      key    = taint.value.key
      value  = try(taint.value.value, null)
      effect = taint.value.effect
    }
  }

  dynamic "update_config" {
    for_each = var.update_config == null ? [] : [var.update_config]

    content {
      max_unavailable            = try(update_config.value.max_unavailable, null)
      max_unavailable_percentage = try(update_config.value.max_unavailable_percentage, null)
    }
  }

  dynamic "remote_access" {
    for_each = var.remote_access != null && var.remote_access.enabled ? [var.remote_access] : []

    content {
      ec2_ssh_key               = try(remote_access.value.ec2_ssh_key, null)
      source_security_group_ids = try(remote_access.value.source_security_groups, null)
    }
  }

  lifecycle {
    precondition {
      condition     = !var.disk_encryption || var.launch_template != null
      error_message = "When disk_encryption is true, launch_template must be provided to control encrypted EBS settings."
    }
  }

  tags = var.tags
}
