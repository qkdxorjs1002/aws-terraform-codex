locals {
  iam_roles = {
    for role in try(var.resources_by_type.iam_roles, []) :
    role.name => role
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

  iam_role_policy_attachments = flatten([
    for role_name, role in local.iam_roles : [
      for policy_arn in try(role.policies, []) : {
        key        = "${role_name}:${policy_arn}"
        role_name  = role_name
        policy_arn = policy_arn
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
          data.http.iam_role_inline_policy_document[try(trimspace(inline_policy.document_url), "")].response_body
        )
      }
    ]
  ])

  iam_role_inline_policy_document_urls = toset(flatten([
    for role in values(local.iam_roles) : [
      for inline_policy in try(role.inline_policies, []) :
      try(trimspace(inline_policy.document_url), "")
      if try(trimspace(inline_policy.document_json), "") == "" && try(trimspace(inline_policy.document_url), "") != ""
    ]
  ]))

  network_acl_associations = flatten([
    for acl_name, acl in local.network_acls : [
      for subnet in try(acl.associated_subnets, []) : {
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
}

data "http" "iam_role_inline_policy_document" {
  for_each = local.iam_role_inline_policy_document_urls

  url = each.value

  request_headers = {
    Accept = "application/json"
  }
}

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

  name                 = each.value.name
  description          = try(each.value.description, null)
  path                 = try(each.value.path, "/")
  assume_role_policy   = try(each.value.assume_role_policy, data.aws_iam_policy_document.default_assume_role.json)
  max_session_duration = try(each.value.max_session_duration, 3600)
  permissions_boundary = try(each.value.permissions_boundary, null)

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

resource "aws_network_acl" "managed" {
  for_each = local.network_acls

  vpc_id = lookup(var.vpc_ids_by_name, each.value.vpc, each.value.vpc)

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

  vpc_id              = lookup(var.vpc_ids_by_name, each.value.vpc, each.value.vpc)
  service_name        = each.value.service
  vpc_endpoint_type   = try(each.value.endpoint_type, "Interface")
  auto_accept         = try(each.value.auto_accept, false)
  private_dns_enabled = try(each.value.private_dns_enabled, null)
  policy              = try(each.value.policy, null)

  subnet_ids = [
    for subnet in try(each.value.subnets, []) :
    lookup(var.subnet_ids_by_name, subnet, subnet)
  ]

  route_table_ids = [
    for route_table in try(each.value.route_tables, []) :
    lookup(var.route_table_ids_by_name, route_table, route_table)
  ]

  security_group_ids = [
    for security_group in try(each.value.security_groups, []) :
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

  vpc_id              = lookup(var.vpc_ids_by_name, each.value.vpc, each.value.vpc)
  service_name        = each.value.service
  vpc_endpoint_type   = try(each.value.endpoint_type, "Interface")
  auto_accept         = try(each.value.auto_accept, false)
  private_dns_enabled = try(each.value.private_dns_enabled, null)
  policy              = try(each.value.policy, null)

  subnet_ids = [
    for subnet in try(each.value.subnets, []) :
    lookup(var.subnet_ids_by_name, subnet, subnet)
  ]

  route_table_ids = [
    for route_table in try(each.value.route_tables, []) :
    lookup(var.route_table_ids_by_name, route_table, route_table)
  ]

  security_group_ids = [
    for security_group in try(each.value.security_groups, []) :
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

  log_destination_type     = try(each.value.destination_type, "cloud-watch-logs")
  log_destination          = each.value.destination_arn
  iam_role_arn             = try(each.value.iam_role_arn, null)
  traffic_type             = try(each.value.traffic_type, "ALL")
  vpc_id                   = lookup(var.vpc_ids_by_name, each.value.vpc, each.value.vpc)
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
