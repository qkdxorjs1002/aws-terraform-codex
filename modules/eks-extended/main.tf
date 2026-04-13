data "aws_caller_identity" "current" {}

locals {
  eks_fargate_profiles = {
    for profile in try(var.resources_by_type.eks_fargate_profiles, []) :
    profile.name => profile
  }

  eks_irsa_roles = {
    for role in try(var.resources_by_type.eks_irsa_roles, []) :
    role.name => role
  }

  eks_helm_releases = {
    for idx, release in try(var.resources_by_type.eks_helm_releases, []) :
    "${release.cluster}:${release.name}:${idx}" => release
  }

  k8s_storage_classes = {
    for idx, storage_class in try(var.resources_by_type.k8s_storage_classes, []) :
    "${storage_class.cluster}:${storage_class.name}:${idx}" => storage_class
  }

  k8s_target_cluster_names = tolist(toset(concat(
    [
      for _, release in local.eks_helm_releases :
      release.cluster
    ],
    [
      for _, storage_class in local.k8s_storage_classes :
      storage_class.cluster
    ]
  )))

  k8s_target_cluster_name = length(local.k8s_target_cluster_names) == 0 ? null : local.k8s_target_cluster_names[0]

  eks_access_entries = {
    for idx, entry in try(var.resources_by_type.eks_access_entries, []) :
    "${entry.cluster}:${entry.principal_arn}:${idx}" => entry
  }

  eks_access_policy_associations = flatten([
    for entry_key, entry in local.eks_access_entries : [
      for idx, policy_association in try(entry.policy_associations, []) : {
        key           = "${entry_key}:${idx}"
        entry_key     = entry_key
        cluster_name  = entry.cluster
        principal_arn = entry.principal_arn
        policy_arn    = policy_association.policy_arn
        access_scope  = try(policy_association.access_scope, { type = "cluster" })
      }
    ]
  ])

  eks_pod_identity_associations = {
    for idx, association in try(var.resources_by_type.eks_pod_identity_associations, []) :
    "${association.cluster}:${association.namespace}:${association.service_account_name}:${idx}" => association
  }

  eks_irsa_managed_policy_attachments = flatten([
    for role_name, role in local.eks_irsa_roles : [
      for policy_arn in try(role.managed_policies, []) : {
        key        = "${role_name}:${policy_arn}"
        role_name  = role_name
        policy_arn = policy_arn
      }
    ]
  ])

  eks_irsa_inline_policies = flatten([
    for role_name, role in local.eks_irsa_roles : [
      for inline_policy in try(role.inline_policies, []) : {
        key         = "${role_name}:${inline_policy.name}"
        role_name   = role_name
        policy_name = inline_policy.name
        policy_json = inline_policy.document_json
      }
    ]
  ])

  eks_irsa_oidc_issuer_by_role = {
    for role_name, role in local.eks_irsa_roles :
    role_name => (
      try(trimspace(role.oidc_provider_issuer_url), "") != "" ?
      role.oidc_provider_issuer_url :
      try(data.aws_eks_cluster.eks_irsa_cluster[role_name].identity[0].oidc[0].issuer, "")
    )
  }

  eks_irsa_role_arns_by_name = {
    for role_name, role in aws_iam_role.eks_irsa :
    role_name => role.arn
  }

  pod_identity_role_arns_by_name = merge(
    var.iam_role_arns_by_name,
    local.eks_irsa_role_arns_by_name
  )

  helm_role_arns_by_name = merge(
    var.iam_role_arns_by_name,
    local.eks_irsa_role_arns_by_name
  )

  helm_base_template_context = {
    cluster_name     = local.k8s_target_cluster_name
    region           = var.region
    vpc              = var.vpc_ids_by_name
    subnet           = var.subnet_ids_by_name
    route_table      = var.route_table_ids_by_name
    security_group   = var.security_group_ids_by_name
    nat_gateway      = var.nat_gateway_ids_by_name
    internet_gateway = var.internet_gateway_ids_by_name
    iam_role         = local.helm_role_arns_by_name
    irsa_role        = local.helm_role_arns_by_name
  }

  helm_template_contexts_by_release = {
    for release_key, release in local.eks_helm_releases :
    release_key => merge(local.helm_base_template_context, {
      release_name = try(release.name, release_key)
      cluster_name = release.cluster
      namespace    = try(release.namespace, "kube-system")
    })
  }

  helm_rendered_values_by_release = {
    for release_key, release in local.eks_helm_releases :
    release_key => (
      try(release.values, null) == null || try(trimspace(release.values), "") == "" ?
      null :
      templatestring(release.values, local.helm_template_contexts_by_release[release_key])
    )
  }

  helm_rendered_set_by_release = {
    for release_key, release in local.eks_helm_releases :
    release_key => [
      for set_item in try(release.set, []) : {
        name = set_item.name
        value = can(templatestring(set_item.value, local.helm_template_contexts_by_release[release_key])) ? templatestring(set_item.value, local.helm_template_contexts_by_release[release_key]) : tostring(set_item.value)
        type = try(set_item.type, "auto")
      }
    ]
  }

  helm_rendered_set_sensitive_by_release = {
    for release_key, release in local.eks_helm_releases :
    release_key => [
      for set_item in try(release.set_sensitive, []) : {
        name = set_item.name
        value = can(templatestring(set_item.value, local.helm_template_contexts_by_release[release_key])) ? templatestring(set_item.value, local.helm_template_contexts_by_release[release_key]) : tostring(set_item.value)
        type = try(set_item.type, "auto")
      }
    ]
  }
}

data "aws_eks_cluster" "eks_irsa_cluster" {
  for_each = {
    for role_name, role in local.eks_irsa_roles :
    role_name => role
    if try(trimspace(role.oidc_provider_issuer_url), "") == "" && try(trimspace(role.cluster), "") != ""
  }

  name = each.value.cluster
}

data "aws_eks_cluster" "helm_target" {
  count = local.k8s_target_cluster_name == null ? 0 : 1

  name = local.k8s_target_cluster_name
}

data "aws_eks_cluster_auth" "helm_target" {
  count = local.k8s_target_cluster_name == null ? 0 : 1

  name = local.k8s_target_cluster_name
}

provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.helm_target[0].endpoint, "https://127.0.0.1")
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.helm_target[0].certificate_authority[0].data), "")
  token                  = try(data.aws_eks_cluster_auth.helm_target[0].token, "")
}

provider "helm" {
  kubernetes {
    host                   = try(data.aws_eks_cluster.helm_target[0].endpoint, "https://127.0.0.1")
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.helm_target[0].certificate_authority[0].data), "")
    token                  = try(data.aws_eks_cluster_auth.helm_target[0].token, "")
  }
}

resource "terraform_data" "eks_helm_single_cluster_guard" {
  input = local.k8s_target_cluster_names

  lifecycle {
    precondition {
      condition     = length(local.k8s_target_cluster_names) <= 1
      error_message = "eks_helm_releases and k8s_storage_classes currently support only one target cluster per spec apply."
    }
  }
}

data "aws_iam_policy_document" "eks_irsa_assume_role" {
  for_each = local.eks_irsa_roles

  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        try(
          each.value.oidc_provider_arn,
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.eks_irsa_oidc_issuer_by_role[each.key], "https://", "")}"
        )
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.eks_irsa_oidc_issuer_by_role[each.key], "https://", "")}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "eks_irsa" {
  for_each = local.eks_irsa_roles

  name               = each.value.name
  assume_role_policy = data.aws_iam_policy_document.eks_irsa_assume_role[each.key].json

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_iam_role_policy_attachment" "eks_irsa" {
  for_each = {
    for attachment in local.eks_irsa_managed_policy_attachments :
    attachment.key => attachment
  }

  role       = aws_iam_role.eks_irsa[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "eks_irsa" {
  for_each = {
    for policy in local.eks_irsa_inline_policies :
    policy.key => policy
  }

  name   = each.value.policy_name
  role   = aws_iam_role.eks_irsa[each.value.role_name].id
  policy = each.value.policy_json
}

resource "aws_eks_fargate_profile" "managed" {
  for_each = local.eks_fargate_profiles

  cluster_name         = each.value.cluster
  fargate_profile_name = each.value.name
  pod_execution_role_arn = try(
    each.value.pod_execution_role_arn,
    lookup(var.iam_role_arns_by_name, each.value.pod_execution_role_name, each.value.pod_execution_role_name)
  )

  subnet_ids = [
    for subnet in try(each.value.subnet_ids, []) :
    lookup(var.subnet_ids_by_name, subnet, subnet)
  ]

  dynamic "selector" {
    for_each = try(each.value.selectors, [])

    content {
      namespace = selector.value.namespace
      labels    = try(selector.value.labels, {})
    }
  }

  tags = try(each.value.tags, {})
}

resource "aws_eks_access_entry" "managed" {
  for_each = local.eks_access_entries

  cluster_name      = each.value.cluster
  principal_arn     = each.value.principal_arn
  kubernetes_groups = try(each.value.kubernetes_groups, [])
  type              = try(each.value.type, "STANDARD")
}

resource "aws_eks_access_policy_association" "managed" {
  for_each = {
    for association in local.eks_access_policy_associations :
    association.key => association
  }

  cluster_name  = each.value.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = try(each.value.access_scope.type, "cluster")
    namespaces = try(each.value.access_scope.namespaces, null)
  }
}

resource "aws_eks_pod_identity_association" "managed" {
  for_each = local.eks_pod_identity_associations

  cluster_name    = each.value.cluster
  namespace       = each.value.namespace
  service_account = each.value.service_account_name
  role_arn        = lookup(local.pod_identity_role_arns_by_name, each.value.role_arn, each.value.role_arn)
}

resource "helm_release" "managed" {
  for_each = local.eks_helm_releases

  name       = each.value.name
  repository = each.value.repository
  chart      = each.value.chart

  namespace        = try(each.value.namespace, "kube-system")
  version          = try(each.value.version, null)
  create_namespace = try(each.value.create_namespace, true)

  timeout           = try(each.value.timeout, 600)
  wait              = try(each.value.wait, true)
  atomic            = try(each.value.atomic, false)
  cleanup_on_fail   = try(each.value.cleanup_on_fail, false)
  dependency_update = try(each.value.dependency_update, false)

  force_update = try(each.value.force_update, false)
  reset_values = try(each.value.reset_values, false)
  reuse_values = try(each.value.reuse_values, false)
  max_history  = try(each.value.max_history, 10)
  skip_crds    = try(each.value.skip_crds, false)

  values = local.helm_rendered_values_by_release[each.key] == null ? [] : [local.helm_rendered_values_by_release[each.key]]

  dynamic "set" {
    for_each = local.helm_rendered_set_by_release[each.key]

    content {
      name  = set.value.name
      value = set.value.value
      type  = set.value.type
    }
  }

  dynamic "set_sensitive" {
    for_each = local.helm_rendered_set_sensitive_by_release[each.key]

    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = set_sensitive.value.type
    }
  }

  depends_on = [
    terraform_data.eks_helm_single_cluster_guard,
    aws_iam_role.eks_irsa,
    aws_iam_role_policy_attachment.eks_irsa,
    aws_iam_role_policy.eks_irsa
  ]
}

resource "kubernetes_storage_class_v1" "managed" {
  for_each = local.k8s_storage_classes

  metadata {
    name        = each.value.name
    annotations = try(each.value.annotations, null)
    labels      = try(each.value.labels, null)
  }

  storage_provisioner    = each.value.provisioner
  reclaim_policy         = try(each.value.reclaim_policy, null)
  volume_binding_mode    = try(each.value.volume_binding_mode, null)
  allow_volume_expansion = try(each.value.allow_volume_expansion, null)
  mount_options          = try(each.value.mount_options, null)
  parameters             = try(each.value.parameters, null)

  dynamic "allowed_topologies" {
    for_each = try(each.value.allowed_topologies, [])

    content {
      dynamic "match_label_expressions" {
        for_each = try(allowed_topologies.value.match_label_expressions, [])

        content {
          key    = match_label_expressions.value.key
          values = try(match_label_expressions.value.values, [])
        }
      }
    }
  }

  depends_on = [
    terraform_data.eks_helm_single_cluster_guard
  ]
}
