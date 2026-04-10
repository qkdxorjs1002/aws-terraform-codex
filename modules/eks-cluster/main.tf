locals {
  use_role_lookup = var.cluster_role_arn == null || trimspace(var.cluster_role_arn) == ""
}

data "aws_iam_role" "cluster" {
  count = local.use_role_lookup ? 1 : 0
  name  = var.cluster_role_name
}

locals {
  effective_cluster_role_arn = local.use_role_lookup ? data.aws_iam_role.cluster[0].arn : var.cluster_role_arn
}

resource "aws_cloudwatch_log_group" "cluster" {
  count = length(var.cluster_logging_enabled_types) > 0 ? 1 : 0

  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = var.tags
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = local.effective_cluster_role_arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = var.cluster_logging_enabled_types

  dynamic "access_config" {
    for_each = var.authentication_mode == null ? [] : [var.authentication_mode]

    content {
      authentication_mode = access_config.value
    }
  }

  dynamic "kubernetes_network_config" {
    for_each = (var.service_ipv4_cidr != null || var.ip_family != null) ? [1] : []

    content {
      service_ipv4_cidr = var.service_ipv4_cidr
      ip_family         = var.ip_family
    }
  }

  dynamic "encryption_config" {
    for_each = var.encryption_enabled && var.encryption_kms_key_arn != null ? [1] : []

    content {
      resources = var.encryption_resources

      provider {
        key_arn = var.encryption_kms_key_arn
      }
    }
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.security_groups
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.cluster]
}
