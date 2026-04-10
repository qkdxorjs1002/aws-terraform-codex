locals {
  effective_addon_version = lower(var.addon_version) == "latest" ? null : var.addon_version

  effective_service_account_role_arn = (
    var.service_account_role_arn == null || trimspace(var.service_account_role_arn) == ""
  ) ? null : var.service_account_role_arn

  effective_configuration_values = (
    var.configuration_values == null || trimspace(var.configuration_values) == ""
  ) ? null : var.configuration_values
}

resource "aws_eks_addon" "this" {
  cluster_name = var.cluster_name
  addon_name   = var.addon_name

  addon_version = local.effective_addon_version

  resolve_conflicts_on_create = var.resolve_conflicts_on_create
  resolve_conflicts_on_update = var.resolve_conflicts_on_update

  service_account_role_arn = local.effective_service_account_role_arn
  configuration_values     = local.effective_configuration_values
  preserve                 = var.preserve
}
