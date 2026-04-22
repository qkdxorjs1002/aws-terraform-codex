locals {
  iam_roles = {
    for role in try(var.resources_by_type.iam_roles, []) :
    role.name => role
  }

  iam_roles_for_instance_profiles = {
    for role_name, role in local.iam_roles :
    role_name => role
    if try(role.create_instance_profile, null) == true || (
      try(role.create_instance_profile, null) != false &&
      (
        try(trimspace(role.assume_role_policy), "") == "" ||
        length(regexall("ec2\\.amazonaws\\.com", tostring(try(role.assume_role_policy, "")))) > 0
      )
    )
  }

  iam_users = {
    for user in try(var.resources_by_type.iam_users, []) :
    user.name => user
  }

  iam_policies = {
    for policy in try(var.resources_by_type.iam_policies, []) :
    policy.name => policy
  }

  iam_oidc_providers = {
    for provider in try(var.resources_by_type.iam_oidc_providers, []) :
    (
      try(trimspace(provider.name), "") != "" ?
      trimspace(provider.name) :
      trimspace(provider.url)
    ) => provider
    if try(trimspace(provider.url), "") != ""
  }

  network_acls = {
    for acl in try(var.resources_by_type.network_acls, []) :
    acl.name => acl
  }

  vpc_endpoints = {
    for endpoint in try(var.resources_by_type.vpc_endpoints, []) :
    endpoint.name => endpoint
  }

  vpc_gateway_endpoints = {
    for endpoint_name, endpoint in local.vpc_endpoints :
    endpoint_name => endpoint
    if lower(try(endpoint.endpoint_type, "Interface")) == "gateway"
  }

  vpc_non_gateway_endpoints = {
    for endpoint_name, endpoint in local.vpc_endpoints :
    endpoint_name => endpoint
    if lower(try(endpoint.endpoint_type, "Interface")) != "gateway"
  }

  vpc_flow_logs = {
    for flow_log in try(var.resources_by_type.vpc_flow_logs, []) :
    flow_log.name => flow_log
  }

  iam_policies_defined = toset(keys(local.iam_policies))

  iam_policy_references = toset([
    for candidate in concat(
      flatten([for role in values(local.iam_roles) : try(role.policies, [])]),
      flatten([for user in values(local.iam_users) : try(user.policies, [])])
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  existing_iam_policy_lookup_names = toset([
    for name in setsubtract(local.iam_policy_references, local.iam_policies_defined) :
    name
    if length(regexall("^arn:", lower(name))) == 0
  ])

  iam_policy_document_urls = toset(concat(
    [
      for inline_policy in flatten([
        for role in values(local.iam_roles) :
        try(role.inline_policies, [])
      ]) :
      try(trimspace(inline_policy.document_url), "")
      if try(trimspace(inline_policy.document_json), "") == "" && try(trimspace(inline_policy.document_url), "") != ""
    ],
    [
      for inline_policy in flatten([
        for user in values(local.iam_users) :
        try(user.inline_policies, [])
      ]) :
      try(trimspace(inline_policy.document_url), "")
      if try(trimspace(inline_policy.document_json), "") == "" && try(trimspace(inline_policy.document_url), "") != ""
    ],
    [
      for policy in values(local.iam_policies) :
      try(trimspace(policy.document_url), "")
      if try(trimspace(policy.document_json), "") == "" && try(trimspace(policy.document_url), "") != ""
    ]
  ))

  existing_iam_policy_arns_by_name = {
    for name, existing_iam_policy in data.aws_iam_policy.existing_by_name :
    name => existing_iam_policy.arn
  }

  iam_policy_arns_by_name = merge(
    local.existing_iam_policy_arns_by_name,
    {
      for name, policy in aws_iam_policy.managed :
      name => policy.arn
    }
  )

  iam_role_policy_attachments = flatten([
    for role_name, role in local.iam_roles : [
      for policy_reference in [
        for policy in try(role.policies, []) :
        trimspace(tostring(policy))
        if try(trimspace(tostring(policy)) != "", false)
        ] : {
        key        = "${role_name}:${policy_reference}"
        role_name  = role_name
        policy_arn = startswith(policy_reference, "arn:") ? policy_reference : lookup(local.iam_policy_arns_by_name, policy_reference, policy_reference)
      }
    ]
  ])

  iam_user_policy_attachments = flatten([
    for user_name, user in local.iam_users : [
      for policy_reference in [
        for policy in try(user.policies, []) :
        trimspace(tostring(policy))
        if try(trimspace(tostring(policy)) != "", false)
        ] : {
        key        = "${user_name}:${policy_reference}"
        user_name  = user_name
        policy_arn = startswith(policy_reference, "arn:") ? policy_reference : lookup(local.iam_policy_arns_by_name, policy_reference, policy_reference)
      }
    ]
  ])

  iam_role_inline_policies = flatten([
    for role_name, role in local.iam_roles : [
      for inline_policy in try(role.inline_policies, []) : {
        key         = "${role_name}:${inline_policy.name}"
        role_name   = role_name
        policy_name = inline_policy.name
        policy_json = (
          try(trimspace(inline_policy.document_json), "") != "" ?
          inline_policy.document_json :
          data.http.iam_policy_document[try(trimspace(inline_policy.document_url), "")].response_body
        )
      }
    ]
  ])

  iam_user_inline_policies = flatten([
    for user_name, user in local.iam_users : [
      for inline_policy in try(user.inline_policies, []) : {
        key         = "${user_name}:${inline_policy.name}"
        user_name   = user_name
        policy_name = inline_policy.name
        policy_json = (
          try(trimspace(inline_policy.document_json), "") != "" ?
          inline_policy.document_json :
          data.http.iam_policy_document[try(trimspace(inline_policy.document_url), "")].response_body
        )
      }
    ]
  ])

  network_acl_associations = flatten([
    for acl_name, acl in local.network_acls : [
      for subnet in distinct(compact(concat(
        try(acl.associated_subnet_ids, []),
        try(acl.associated_subnet_names, []),
        try(acl.associated_subnets, [])
        ))) : {
        key       = "${acl_name}:${subnet}"
        acl_name  = acl_name
        subnet_id = lookup(var.subnet_ids_by_name, subnet, subnet)
      }
    ]
  ])

  iam_role_arns_by_name = {
    for name, role in aws_iam_role.managed :
    name => role.arn
  }

  cloudfront_distribution_attributes_by_name = {
    for distribution in try(var.resources_by_type.cloudfront_distributions, []) :
    distribution.name => {
      name            = distribution.name
      distribution_id = try(trimspace(distribution.distribution_id), "")
      arn = (
        try(trimspace(lookup(var.cloudfront_distribution_arns_by_name, distribution.name, "")), "") != "" ? trimspace(lookup(var.cloudfront_distribution_arns_by_name, distribution.name, "")) :
        try(trimspace(distribution.distribution_arn), "") != "" ? trimspace(distribution.distribution_arn) :
        try(trimspace(distribution.arn), "") != "" ? trimspace(distribution.arn) :
        try(trimspace(distribution.distribution_id), "") != "" ? "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${trimspace(distribution.distribution_id)}" :
        ""
      )
    }
    if try(trimspace(distribution.name), "") != ""
  }

  iam_oidc_provider_attributes_by_lookup = merge(
    {
      for key, provider in aws_iam_openid_connect_provider.managed :
      key => {
        arn = provider.arn
        url = provider.url
      }
    },
    {
      for _, provider in aws_iam_openid_connect_provider.managed :
      provider.url => {
        arn = provider.arn
        url = provider.url
      }
    }
  )

  iam_assume_role_templatestring_context = {
    oidc_provider           = local.iam_oidc_provider_attributes_by_lookup
    iam_oidc_provider       = local.iam_oidc_provider_attributes_by_lookup
  }

  iam_policy_templatestring_context = {
    oidc_provider           = local.iam_oidc_provider_attributes_by_lookup
    iam_oidc_provider       = local.iam_oidc_provider_attributes_by_lookup
    cloudfront_distribution = local.cloudfront_distribution_attributes_by_name
  }
}

data "http" "iam_policy_document" {
  for_each = local.iam_policy_document_urls

  url = each.value

  request_headers = {
    Accept = "application/json"
  }
}

data "aws_iam_policy" "existing_by_name" {
  for_each = local.existing_iam_policy_lookup_names
  name     = each.value
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "default_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "managed" {
  for_each = local.iam_roles

  name        = each.value.name
  description = try(each.value.description, null)
  path        = try(each.value.path, "/")
  assume_role_policy = (
    try(trimspace(each.value.assume_role_policy), "") != "" ?
    templatestring(each.value.assume_role_policy, local.iam_assume_role_templatestring_context) :
    data.aws_iam_policy_document.default_assume_role.json
  )
  max_session_duration = try(each.value.max_session_duration, 3600)
  permissions_boundary = try(each.value.permissions_boundary, null)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_iam_instance_profile" "managed" {
  for_each = local.iam_roles_for_instance_profiles

  name = each.value.name
  path = try(each.value.path, "/")
  role = aws_iam_role.managed[each.key].name

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_iam_openid_connect_provider" "managed" {
  for_each = local.iam_oidc_providers

  url             = each.value.url
  client_id_list  = try(each.value.client_id_list, ["sts.amazonaws.com"])
  thumbprint_list = try(each.value.thumbprint_list, null)

  tags = merge(
    {
      Name = try(each.value.name, each.key)
    },
    try(each.value.tags, {})
  )
}

resource "aws_iam_policy" "managed" {
  for_each = local.iam_policies

  name        = each.value.name
  description = try(each.value.description, null)
  path        = try(each.value.path, "/")
  policy = (
    try(trimspace(each.value.document_json), "") != "" ?
    (
      can(templatestring(
        each.value.document_json,
        local.iam_policy_templatestring_context
      )) ?
      templatestring(
        each.value.document_json,
        local.iam_policy_templatestring_context
      ) :
      each.value.document_json
    ) :
    data.http.iam_policy_document[try(trimspace(each.value.document_url), "")].response_body
  )

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    for attachment in local.iam_role_policy_attachments :
    attachment.key => attachment
  }

  role       = aws_iam_role.managed[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "managed" {
  for_each = {
    for policy in local.iam_role_inline_policies :
    policy.key => policy
  }

  name   = each.value.policy_name
  role   = aws_iam_role.managed[each.value.role_name].id
  policy = each.value.policy_json
}

resource "aws_iam_user" "managed" {
  for_each = local.iam_users

  name                 = each.value.name
  path                 = try(each.value.path, "/")
  permissions_boundary = try(each.value.permissions_boundary, null)
  force_destroy        = try(each.value.force_destroy, false)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_iam_user_policy_attachment" "managed" {
  for_each = {
    for attachment in local.iam_user_policy_attachments :
    attachment.key => attachment
  }

  user       = aws_iam_user.managed[each.value.user_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_user_policy" "managed" {
  for_each = {
    for policy in local.iam_user_inline_policies :
    policy.key => policy
  }

  name   = each.value.policy_name
  user   = aws_iam_user.managed[each.value.user_name].name
  policy = each.value.policy_json
}

resource "aws_network_acl" "managed" {
  for_each = local.network_acls

  vpc_id = lookup(
    var.vpc_ids_by_name,
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null)),
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null))
  )

  dynamic "ingress" {
    for_each = try(each.value.ingress_rules, [])

    content {
      rule_no         = ingress.value.rule_number
      protocol        = tostring(try(ingress.value.protocol, "-1"))
      action          = lower(try(ingress.value.action, "allow"))
      cidr_block      = try(ingress.value.cidr_block, null)
      ipv6_cidr_block = try(ingress.value.ipv6_cidr_block, null)
      from_port       = try(ingress.value.from_port, 0)
      to_port         = try(ingress.value.to_port, 0)
    }
  }

  dynamic "egress" {
    for_each = try(each.value.egress_rules, [])

    content {
      rule_no         = egress.value.rule_number
      protocol        = tostring(try(egress.value.protocol, "-1"))
      action          = lower(try(egress.value.action, "allow"))
      cidr_block      = try(egress.value.cidr_block, null)
      ipv6_cidr_block = try(egress.value.ipv6_cidr_block, null)
      from_port       = try(egress.value.from_port, 0)
      to_port         = try(egress.value.to_port, 0)
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_network_acl_association" "managed" {
  for_each = {
    for association in local.network_acl_associations :
    association.key => association
  }

  network_acl_id = aws_network_acl.managed[each.value.acl_name].id
  subnet_id      = each.value.subnet_id
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.vpc_gateway_endpoints

  vpc_id = lookup(
    var.vpc_ids_by_name,
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null)),
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null))
  )
  service_name        = each.value.service
  vpc_endpoint_type   = try(each.value.endpoint_type, "Interface")
  auto_accept         = try(each.value.auto_accept, false)
  private_dns_enabled = try(each.value.private_dns_enabled, null)
  policy              = try(each.value.policy, null)

  subnet_ids = [
    for subnet in distinct(compact(concat(
      try(each.value.subnet_ids, []),
      try(each.value.subnet_names, []),
      try(each.value.subnets, [])
    ))) :
    lookup(var.subnet_ids_by_name, subnet, subnet)
  ]

  route_table_ids = [
    for route_table in distinct(compact(concat(
      try(each.value.route_table_ids, []),
      try(each.value.route_table_names, []),
      try(each.value.route_tables, [])
    ))) :
    lookup(var.route_table_ids_by_name, route_table, route_table)
  ]

  security_group_ids = [
    for security_group in distinct(compact(concat(
      try(each.value.security_group_ids, []),
      try(each.value.security_group_names, []),
      try(each.value.security_groups, [])
    ))) :
    lookup(var.security_group_ids_by_name, security_group, security_group)
  ]

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_vpc_endpoint" "managed" {
  for_each = local.vpc_non_gateway_endpoints

  vpc_id = lookup(
    var.vpc_ids_by_name,
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null)),
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null))
  )
  service_name        = each.value.service
  vpc_endpoint_type   = try(each.value.endpoint_type, "Interface")
  auto_accept         = try(each.value.auto_accept, false)
  private_dns_enabled = try(each.value.private_dns_enabled, null)
  policy              = try(each.value.policy, null)

  subnet_ids = [
    for subnet in distinct(compact(concat(
      try(each.value.subnet_ids, []),
      try(each.value.subnet_names, []),
      try(each.value.subnets, [])
    ))) :
    lookup(var.subnet_ids_by_name, subnet, subnet)
  ]

  route_table_ids = [
    for route_table in distinct(compact(concat(
      try(each.value.route_table_ids, []),
      try(each.value.route_table_names, []),
      try(each.value.route_tables, [])
    ))) :
    lookup(var.route_table_ids_by_name, route_table, route_table)
  ]

  security_group_ids = [
    for security_group in distinct(compact(concat(
      try(each.value.security_group_ids, []),
      try(each.value.security_group_names, []),
      try(each.value.security_groups, [])
    ))) :
    lookup(var.security_group_ids_by_name, security_group, security_group)
  ]

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )

  depends_on = [aws_vpc_endpoint.gateway]
}

resource "aws_flow_log" "managed" {
  for_each = local.vpc_flow_logs

  log_destination_type = try(each.value.destination_type, "cloud-watch-logs")
  log_destination      = each.value.destination_arn
  iam_role_arn         = try(each.value.iam_role_arn, null)
  traffic_type         = try(each.value.traffic_type, "ALL")
  vpc_id = lookup(
    var.vpc_ids_by_name,
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null)),
    coalesce(try(each.value.vpc_id, null), try(each.value.vpc_name, null), try(each.value.vpc, null))
  )
  max_aggregation_interval = try(each.value.max_aggregation_interval, 600)
  log_format               = try(each.value.log_format, null)

  dynamic "destination_options" {
    for_each = try(each.value.destination_options, null) == null ? [] : [each.value.destination_options]

    content {
      file_format                = try(destination_options.value.file_format, "plain-text")
      hive_compatible_partitions = try(destination_options.value.hive_compatible_partitions, false)
      per_hour_partition         = try(destination_options.value.per_hour_partition, false)
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}
