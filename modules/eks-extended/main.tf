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

  k8s_deployments = {
    for idx, deployment in try(var.resources_by_type.k8s_deployments, []) :
    "${deployment.cluster}:${deployment.name}:${idx}" => deployment
  }

  k8s_services = {
    for idx, service in try(var.resources_by_type.k8s_services, []) :
    "${service.cluster}:${service.name}:${idx}" => service
  }

  k8s_target_group_bindings = {
    for idx, binding in try(var.resources_by_type.k8s_target_group_bindings, []) :
    "${binding.cluster}:${binding.name}:${idx}" => binding
  }

  k8s_target_group_binding_cluster_names = toset([
    for _, binding in local.k8s_target_group_bindings :
    binding.cluster
  ])

  aws_load_balancer_controller_release_keys_for_bindings = toset([
    for release_key, release in local.eks_helm_releases :
    release_key
    if contains(local.k8s_target_group_binding_cluster_names, release.cluster) && (
      try(trimspace(release.name), "") == "aws-load-balancer-controller" ||
      try(trimspace(release.chart), "") == "aws-load-balancer-controller"
    )
  ])

  k8s_target_cluster_names = tolist(toset(concat(
    [
      for _, release in local.eks_helm_releases :
      release.cluster
    ],
    [
      for _, storage_class in local.k8s_storage_classes :
      storage_class.cluster
    ],
    [
      for _, deployment in local.k8s_deployments :
      deployment.cluster
    ],
    [
      for _, service in local.k8s_services :
      service.cluster
    ],
    [
      for _, binding in local.k8s_target_group_bindings :
      binding.cluster
    ]
  )))

  k8s_target_cluster_name = length(local.k8s_target_cluster_names) == 0 ? null : local.k8s_target_cluster_names[0]

  eks_access_entries = {
    for entry in try(var.resources_by_type.eks_access_entries, []) :
    "${entry.cluster}:${entry.principal_arn}" => entry
  }

  eks_access_policy_associations = flatten([
    for entry_key, entry in local.eks_access_entries : [
      for policy_association in try(entry.policy_associations, []) : {
        key = format(
          "%s:%s:%s:%s",
          entry.cluster,
          entry.principal_arn,
          policy_association.policy_arn,
          sha1(jsonencode({
            type       = try(policy_association.access_scope.type, "cluster")
            namespaces = sort(try(policy_association.access_scope.namespaces, []))
          }))
        )
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
        policy_json = (
          try(trimspace(inline_policy.document_json), "") != "" ?
          inline_policy.document_json :
          data.http.eks_irsa_inline_policy_document[try(trimspace(inline_policy.document_url), "")].response_body
        )
      }
    ]
  ])

  eks_irsa_inline_policy_document_urls = toset(flatten([
    for role in values(local.eks_irsa_roles) : [
      for inline_policy in try(role.inline_policies, []) :
      try(trimspace(inline_policy.document_url), "")
      if try(trimspace(inline_policy.document_json), "") == "" && try(trimspace(inline_policy.document_url), "") != ""
    ]
  ]))

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
    release_key => concat(
      [
        for set_item in try(release.set, []) : {
          name  = set_item.name
          value = can(templatestring(set_item.value, local.helm_template_contexts_by_release[release_key])) ? templatestring(set_item.value, local.helm_template_contexts_by_release[release_key]) : tostring(set_item.value)
          type  = try(set_item.type, "auto")
        }
      ],
      try(trimspace(release.image_pull_policy), "") != "" && !contains([for set_item in try(release.set, []) : set_item.name], "image.pullPolicy") ? [
        {
          name  = "image.pullPolicy"
          value = can(templatestring(release.image_pull_policy, local.helm_template_contexts_by_release[release_key])) ? templatestring(release.image_pull_policy, local.helm_template_contexts_by_release[release_key]) : tostring(release.image_pull_policy)
          type  = "string"
        }
      ] : []
    )
  }

  helm_rendered_set_sensitive_by_release = {
    for release_key, release in local.eks_helm_releases :
    release_key => [
      for set_item in try(release.set_sensitive, []) : {
        name  = set_item.name
        value = can(templatestring(set_item.value, local.helm_template_contexts_by_release[release_key])) ? templatestring(set_item.value, local.helm_template_contexts_by_release[release_key]) : tostring(set_item.value)
        type  = try(set_item.type, "auto")
      }
    ]
  }

  helm_ecr_oci_repository_pattern = "^oci://([0-9]{12})\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com(\\.cn)?(?:/.*)?$"

  helm_ecr_oci_registry_id_by_release = {
    for release_key, release in local.eks_helm_releases :
    release_key => regex(local.helm_ecr_oci_repository_pattern, try(trimspace(release.repository), ""))[0]
    if length(regexall(local.helm_ecr_oci_repository_pattern, try(trimspace(release.repository), ""))) > 0
  }

  helm_ecr_oci_registry_ids = toset(values(local.helm_ecr_oci_registry_id_by_release))

  helm_repository_username_by_release = {
    for release_key, registry_id in local.helm_ecr_oci_registry_id_by_release :
    release_key => "AWS"
  }

  helm_repository_password_by_release = {
    for release_key, registry_id in local.helm_ecr_oci_registry_id_by_release :
    release_key => trimprefix(base64decode(data.aws_ecr_authorization_token.helm_oci_registry[registry_id].authorization_token), "AWS:")
  }

  k8s_target_group_binding_manifests = {
    for binding_key, binding in local.k8s_target_group_bindings :
    binding_key => {
      apiVersion = "elbv2.k8s.aws/v1beta1"
      kind       = "TargetGroupBinding"
      metadata = {
        name        = binding.name
        namespace   = try(binding.namespace, "default")
        labels      = try(binding.labels, null)
        annotations = try(binding.annotations, null)
      }
      spec = merge(
        {
          serviceRef = {
            name = binding.service_name
            port = try(binding.service_port, 80)
          }
        },
        try(trimspace(tostring(binding.target_group_arn)), "") != "" ? { targetGroupARN = binding.target_group_arn } : {},
        try(trimspace(tostring(binding.target_group_name)), "") != "" ? { targetGroupName = binding.target_group_name } : {},
        try(trimspace(tostring(binding.target_type)), "") != "" ? { targetType = binding.target_type } : {},
        try(trimspace(tostring(binding.vpc_id)), "") != "" ? { vpcID = binding.vpc_id } : {},
        try(trimspace(tostring(binding.ip_address_type)), "") != "" ? { ipAddressType = binding.ip_address_type } : {},
        try(binding.networking, null) == null ? {} : { networking = binding.networking }
      )
    }
  }

  aws_cli_profile_args           = try(trimspace(var.profile), "") != "" ? ["--profile", trimspace(var.profile)] : []
  aws_cli_profile_arg_string     = try(trimspace(var.profile), "") != "" ? " --profile '${trimspace(var.profile)}'" : ""
  k8s_exec_cluster_name_or_empty = coalesce(local.k8s_target_cluster_name, "")
}

data "aws_eks_cluster" "eks_irsa_cluster" {
  for_each = {
    for role_name, role in local.eks_irsa_roles :
    role_name => role
    if try(trimspace(role.oidc_provider_issuer_url), "") == "" && try(trimspace(role.cluster), "") != ""
  }

  name = each.value.cluster

  depends_on = [terraform_data.eks_cluster_prerequisites]
}

resource "terraform_data" "eks_cluster_prerequisites" {
  input = {
    clusters = var.eks_cluster_dependency_arns
  }
}

resource "terraform_data" "eks_runtime_prerequisites" {
  input = {
    clusters    = var.eks_cluster_dependency_arns
    node_groups = var.eks_node_group_dependency_arns
    addons      = var.eks_addon_dependency_arns
  }
}

data "aws_eks_cluster" "helm_target" {
  count = local.k8s_target_cluster_name == null ? 0 : 1

  name = local.k8s_target_cluster_name

  depends_on = [terraform_data.eks_cluster_prerequisites]
}

data "aws_ecr_authorization_token" "helm_oci_registry" {
  for_each = local.helm_ecr_oci_registry_ids

  registry_id = each.value
}

data "http" "eks_irsa_inline_policy_document" {
  for_each = local.eks_irsa_inline_policy_document_urls

  url = each.value

  request_headers = {
    Accept = "application/json"
  }
}

provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.helm_target[0].endpoint, "https://127.0.0.1")
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.helm_target[0].certificate_authority[0].data), "")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      [
        "eks",
        "get-token",
        "--cluster-name",
        local.k8s_exec_cluster_name_or_empty,
        "--region",
        var.region
      ],
      local.aws_cli_profile_args
    )
  }
}

provider "helm" {
  kubernetes {
    host                   = try(data.aws_eks_cluster.helm_target[0].endpoint, "https://127.0.0.1")
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.helm_target[0].certificate_authority[0].data), "")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        [
          "eks",
          "get-token",
          "--cluster-name",
          local.k8s_exec_cluster_name_or_empty,
          "--region",
          var.region
        ],
        local.aws_cli_profile_args
      )
    }
  }
}

resource "terraform_data" "eks_helm_single_cluster_guard" {
  input = local.k8s_target_cluster_names

  lifecycle {
    precondition {
      condition     = length(local.k8s_target_cluster_names) <= 1
      error_message = "eks_helm_releases, k8s_storage_classes, k8s_deployments, k8s_services, and k8s_target_group_bindings currently support only one target cluster per spec apply."
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

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )

  depends_on = [terraform_data.eks_cluster_prerequisites]
}

resource "aws_eks_access_entry" "managed" {
  for_each = local.eks_access_entries

  cluster_name      = each.value.cluster
  principal_arn     = each.value.principal_arn
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  type              = try(each.value.type, "STANDARD")

  depends_on = [terraform_data.eks_cluster_prerequisites]
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

  depends_on = [
    terraform_data.eks_cluster_prerequisites,
    aws_eks_access_entry.managed
  ]
}

resource "aws_eks_pod_identity_association" "managed" {
  for_each = local.eks_pod_identity_associations

  cluster_name    = each.value.cluster
  namespace       = each.value.namespace
  service_account = each.value.service_account_name
  role_arn        = lookup(local.pod_identity_role_arns_by_name, each.value.role_arn, each.value.role_arn)

  depends_on = [
    terraform_data.eks_runtime_prerequisites,
    aws_eks_access_entry.managed,
    aws_eks_access_policy_association.managed,
    helm_release.managed
  ]
}

resource "helm_release" "managed" {
  for_each = local.eks_helm_releases

  name                = each.value.name
  repository          = each.value.repository
  chart               = each.value.chart
  repository_username = lookup(local.helm_repository_username_by_release, each.key, null)
  repository_password = lookup(local.helm_repository_password_by_release, each.key, null)

  namespace        = try(each.value.namespace, "kube-system")
  version          = try(each.value.version, null)
  create_namespace = try(each.value.create_namespace, true)

  timeout           = try(each.value.timeout, 600)
  wait              = try(each.value.wait, true)
  wait_for_jobs     = try(each.value.wait_for_jobs, false)
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

  lifecycle {
    # ECR OCI auth token rotates frequently and causes no-op in-place updates.
    ignore_changes = [repository_password]
  }

  depends_on = [
    terraform_data.eks_runtime_prerequisites,
    terraform_data.eks_helm_single_cluster_guard,
    aws_iam_role.eks_irsa,
    aws_iam_role_policy_attachment.eks_irsa,
    aws_iam_role_policy.eks_irsa,
    aws_eks_access_entry.managed,
    aws_eks_access_policy_association.managed
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
    terraform_data.eks_runtime_prerequisites,
    terraform_data.eks_helm_single_cluster_guard,
    aws_eks_access_entry.managed,
    aws_eks_access_policy_association.managed
  ]
}

resource "kubernetes_deployment_v1" "managed" {
  for_each = local.k8s_deployments

  metadata {
    name        = each.value.name
    namespace   = try(each.value.namespace, "default")
    labels      = try(each.value.labels, null)
    annotations = try(each.value.annotations, null)
  }

  spec {
    replicas = try(each.value.replicas, 1)

    selector {
      match_labels = try(each.value.selector_match_labels, { app = each.value.name })
    }

    template {
      metadata {
        labels = try(
          each.value.pod_labels,
          try(each.value.selector_match_labels, { app = each.value.name })
        )
        annotations = try(each.value.pod_annotations, null)
      }

      spec {
        dynamic "container" {
          for_each = try(each.value.containers, [])

          content {
            name              = container.value.name
            image             = container.value.image
            image_pull_policy = try(container.value.image_pull_policy, null)
            command           = try(container.value.command, null)
            args              = try(container.value.args, null)

            dynamic "port" {
              for_each = try(container.value.ports, [])

              content {
                name           = try(port.value.name, null)
                container_port = port.value.container_port
                protocol       = try(port.value.protocol, null)
              }
            }

            dynamic "env" {
              for_each = try(container.value.env, [])

              content {
                name  = env.value.name
                value = try(env.value.value, null)
              }
            }

            dynamic "resources" {
              for_each = try(container.value.resources, null) == null ? [] : [container.value.resources]

              content {
                limits   = try(resources.value.limits, null)
                requests = try(resources.value.requests, null)
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    terraform_data.eks_runtime_prerequisites,
    terraform_data.eks_helm_single_cluster_guard,
    aws_eks_access_entry.managed,
    aws_eks_access_policy_association.managed,
    helm_release.managed
  ]
}

resource "kubernetes_service_v1" "managed" {
  for_each = local.k8s_services

  metadata {
    name        = each.value.name
    namespace   = try(each.value.namespace, "default")
    labels      = try(each.value.labels, null)
    annotations = try(each.value.annotations, null)
  }

  spec {
    selector                          = try(each.value.selector, { app = each.value.name })
    type                              = try(each.value.type, null)
    session_affinity                  = try(each.value.session_affinity, null)
    publish_not_ready_addresses       = try(each.value.publish_not_ready_addresses, null)
    internal_traffic_policy           = try(each.value.internal_traffic_policy, null)
    external_traffic_policy           = try(each.value.external_traffic_policy, null)
    allocate_load_balancer_node_ports = try(each.value.allocate_load_balancer_node_ports, null)
    load_balancer_class               = try(each.value.load_balancer_class, null)
    external_ips                      = try(each.value.external_ips, null)
    load_balancer_ip                  = try(each.value.load_balancer_ip, null)
    load_balancer_source_ranges       = try(each.value.load_balancer_source_ranges, null)

    dynamic "port" {
      for_each = try(each.value.ports, [])

      content {
        name        = try(port.value.name, null)
        port        = port.value.port
        target_port = try(port.value.target_port, null)
        protocol    = try(port.value.protocol, null)
        node_port   = try(port.value.node_port, null)
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(try(each.value.ports, [])) > 0
      error_message = "k8s_services requires at least one port entry."
    }
  }

  depends_on = [
    terraform_data.eks_runtime_prerequisites,
    terraform_data.eks_helm_single_cluster_guard,
    aws_eks_access_entry.managed,
    aws_eks_access_policy_association.managed,
    helm_release.managed,
    kubernetes_deployment_v1.managed
  ]
}

resource "terraform_data" "target_group_binding_webhook_warmup" {
  for_each = local.aws_load_balancer_controller_release_keys_for_bindings

  input = {
    cluster = local.eks_helm_releases[each.key].cluster
    release = local.eks_helm_releases[each.key].name
  }

  provisioner "local-exec" {
    command = "sleep 30"
  }

  depends_on = [
    helm_release.managed
  ]
}

resource "terraform_data" "target_group_binding" {
  for_each = local.k8s_target_group_bindings

  input = {
    cluster_name        = each.value.cluster
    binding_name        = each.value.name
    region              = var.region
    profile_arg_string  = local.aws_cli_profile_arg_string
    binding_json        = jsonencode(local.k8s_target_group_binding_manifests[each.key])
    manifest_hash       = sha1(jsonencode(local.k8s_target_group_binding_manifests[each.key]))
  }

  triggers_replace = [
    sha1(jsonencode(local.k8s_target_group_binding_manifests[each.key]))
  ]

  lifecycle {
    precondition {
      condition = (
        try(trimspace(tostring(each.value.target_group_arn)), "") != "" ||
        try(trimspace(tostring(each.value.target_group_name)), "") != ""
      )
      error_message = "k8s_target_group_bindings requires either target_group_arn or target_group_name."
    }
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      command -v aws >/dev/null
      command -v kubectl >/dev/null

      kubeconfig_file="$(mktemp)"
      trap 'rm -f "$kubeconfig_file"' EXIT

      aws eks update-kubeconfig --name '${self.input.cluster_name}' --region '${self.input.region}'${self.input.profile_arg_string} --kubeconfig "$kubeconfig_file" --alias '${self.input.cluster_name}' >/dev/null

      cat <<'MANIFEST' | kubectl --kubeconfig "$kubeconfig_file" --context '${self.input.cluster_name}' apply -f -
      ${self.input.binding_json}
      MANIFEST
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      if ! command -v aws >/dev/null || ! command -v kubectl >/dev/null; then
        exit 0
      fi

      kubeconfig_file="$(mktemp)"
      trap 'rm -f "$kubeconfig_file"' EXIT

      aws eks update-kubeconfig --name '${self.input.cluster_name}' --region '${self.input.region}'${self.input.profile_arg_string} --kubeconfig "$kubeconfig_file" --alias '${self.input.cluster_name}' >/dev/null

      cat <<'MANIFEST' | kubectl --kubeconfig "$kubeconfig_file" --context '${self.input.cluster_name}' delete --ignore-not-found -f -
      ${self.input.binding_json}
      MANIFEST
    EOT
  }

  depends_on = [
    terraform_data.eks_runtime_prerequisites,
    terraform_data.eks_helm_single_cluster_guard,
    terraform_data.target_group_binding_webhook_warmup,
    aws_eks_access_entry.managed,
    aws_eks_access_policy_association.managed,
    helm_release.managed,
    kubernetes_service_v1.managed
  ]
}
