locals {
  spec = yamldecode(file("${path.module}/${var.spec_file}"))

  project = local.spec.project

  project_environment = trimspace(try(local.project.environment, try(local.project.env, "")))
  project_managed_by  = trimspace(try(local.project.managed_by, ""))
  project_maintainer  = trimspace(try(local.project.maintainer, ""))
  project_global_tags = merge(
    local.project_environment != "" ? { Environment = local.project_environment } : {},
    local.project_managed_by != "" ? { ManagedBy = local.project_managed_by } : {},
    local.project_maintainer != "" ? { Maintainer = local.project_maintainer } : {}
  )

  resource_types = toset(flatten([
    for resource in local.project.resources : keys(resource)
  ]))

  resources_by_type = {
    for resource_type in local.resource_types :
    resource_type => flatten([
      for resource in local.project.resources :
      try(resource[resource_type], [])
    ])
  }

  vpcs = {
    for vpc in try(local.resources_by_type.vpcs, []) :
    vpc.name => vpc
  }

  subnets = {
    for subnet in try(local.resources_by_type.subnets, []) :
    subnet.name => subnet
  }

  internet_gateways = {
    for igw in try(local.resources_by_type.internet_gateways, []) :
    igw.name => igw
  }

  nat_gateways = {
    for nat in try(local.resources_by_type.nat_gateways, []) :
    nat.name => nat
  }

  route_tables = {
    for route_table in try(local.resources_by_type.route_tables, []) :
    route_table.name => route_table
  }

  security_groups = {
    for security_group in try(local.resources_by_type.security_groups, []) :
    security_group.name => security_group
  }

  security_group_names = toset(keys(local.security_groups))

  addon_configuration_value_strings = [
    for addon in try(local.resources_by_type.eks_addons, []) :
    try(addon.configuration_values, "")
  ]

  addon_subnet_reference_names = toset(flatten([
    for configuration_values in local.addon_configuration_value_strings : [
      for token in regexall("\\$\\{\\s*subnet\\[\\\"[^\\\"]+\\\"\\]\\s*\\}", configuration_values) :
      regex("^\\$\\{\\s*subnet\\[\\\"([^\\\"]+)\\\"\\]\\s*\\}$", token)[0]
    ]
  ]))

  addon_security_group_reference_names = toset(flatten([
    for configuration_values in local.addon_configuration_value_strings : [
      for token in regexall("\\$\\{\\s*security_group\\[\\\"[^\\\"]+\\\"\\]\\s*\\}", configuration_values) :
      regex("^\\$\\{\\s*security_group\\[\\\"([^\\\"]+)\\\"\\]\\s*\\}$", token)[0]
    ]
  ]))

  addon_vpc_reference_names = toset(flatten([
    for configuration_values in local.addon_configuration_value_strings : [
      for token in regexall("\\$\\{\\s*vpc\\[\\\"[^\\\"]+\\\"\\]\\s*\\}", configuration_values) :
      regex("^\\$\\{\\s*vpc\\[\\\"([^\\\"]+)\\\"\\]\\s*\\}$", token)[0]
    ]
  ]))

  addon_route_table_reference_names = toset(flatten([
    for configuration_values in local.addon_configuration_value_strings : [
      for token in regexall("\\$\\{\\s*route_table\\[\\\"[^\\\"]+\\\"\\]\\s*\\}", configuration_values) :
      regex("^\\$\\{\\s*route_table\\[\\\"([^\\\"]+)\\\"\\]\\s*\\}$", token)[0]
    ]
  ]))

  addon_nat_gateway_reference_names = toset(flatten([
    for configuration_values in local.addon_configuration_value_strings : [
      for token in regexall("\\$\\{\\s*nat_gateway\\[\\\"[^\\\"]+\\\"\\]\\s*\\}", configuration_values) :
      regex("^\\$\\{\\s*nat_gateway\\[\\\"([^\\\"]+)\\\"\\]\\s*\\}$", token)[0]
    ]
  ]))

  addon_internet_gateway_reference_names = toset(flatten([
    for configuration_values in local.addon_configuration_value_strings : [
      for token in regexall("\\$\\{\\s*internet_gateway\\[\\\"[^\\\"]+\\\"\\]\\s*\\}", configuration_values) :
      regex("^\\$\\{\\s*internet_gateway\\[\\\"([^\\\"]+)\\\"\\]\\s*\\}$", token)[0]
    ]
  ]))

  vpc_lookup_names = toset([
    for candidate in concat(
      [for vpc in try(local.resources_by_type.vpcs, []) : try(vpc.name, null)],
      [for subnet in try(local.resources_by_type.subnets, []) : try(subnet.vpc, null)],
      [for internet_gateway in try(local.resources_by_type.internet_gateways, []) : try(internet_gateway.vpc, null)],
      [for route_table in try(local.resources_by_type.route_tables, []) : try(route_table.vpc, null)],
      [for security_group in try(local.resources_by_type.security_groups, []) : try(security_group.vpc, null)],
      [for endpoint in try(local.resources_by_type.vpc_endpoints, []) : try(endpoint.vpc, null)],
      [for network_acl in try(local.resources_by_type.network_acls, []) : try(network_acl.vpc, null)],
      [for flow_log in try(local.resources_by_type.vpc_flow_logs, []) : try(flow_log.vpc, null)],
      [for alb in try(local.resources_by_type.albs, []) : try(alb.vpc, null)],
      [for cluster in try(local.resources_by_type.eks_clusters, []) : try(cluster.vpc, null)],
      tolist(local.addon_vpc_reference_names)
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  subnet_lookup_names = toset([
    for candidate in concat(
      [for subnet in try(local.resources_by_type.subnets, []) : try(subnet.name, null)],
      [for nat_gateway in try(local.resources_by_type.nat_gateways, []) : try(nat_gateway.subnet, null)],
      flatten([for route_table in try(local.resources_by_type.route_tables, []) : try(route_table.associated_subnets, [])]),
      flatten([for endpoint in try(local.resources_by_type.vpc_endpoints, []) : try(endpoint.subnets, [])]),
      flatten([for network_acl in try(local.resources_by_type.network_acls, []) : try(network_acl.associated_subnets, [])]),
      [for ec2 in try(local.resources_by_type.ec2_instances, []) : try(ec2.subnet, null)],
      flatten([for rds in try(local.resources_by_type.rds_instances, []) : try(rds.subnets, [])]),
      flatten([for cluster in try(local.resources_by_type.eks_clusters, []) : try(cluster.subnet_ids, [])]),
      flatten([for node_group in try(local.resources_by_type.eks_node_groups, []) : try(node_group.subnet_ids, [])]),
      flatten([for fargate_profile in try(local.resources_by_type.eks_fargate_profiles, []) : try(fargate_profile.subnet_ids, [])]),
      flatten([for lambda_function in try(local.resources_by_type.lambda_functions, []) : try(lambda_function.vpc_config.subnet_ids, [])]),
      flatten([for ecs_service in try(local.resources_by_type.ecs_services, []) : try(ecs_service.network_configuration.subnets, [])]),
      tolist(local.addon_subnet_reference_names)
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  security_group_lookup_names = toset([
    for candidate in concat(
      [for security_group in try(local.resources_by_type.security_groups, []) : try(security_group.name, null)],
      flatten([for cluster in try(local.resources_by_type.eks_clusters, []) : try(cluster.security_groups, [])]),
      flatten([for node_group in try(local.resources_by_type.eks_node_groups, []) : try(node_group.remote_access.source_security_groups, [])]),
      flatten([for endpoint in try(local.resources_by_type.vpc_endpoints, []) : try(endpoint.security_groups, [])]),
      flatten([for ec2 in try(local.resources_by_type.ec2_instances, []) : try(ec2.security_groups, [])]),
      flatten([for alb in try(local.resources_by_type.albs, []) : try(alb.security_groups, [])]),
      flatten([for lambda_function in try(local.resources_by_type.lambda_functions, []) : try(lambda_function.vpc_config.security_group_ids, [])]),
      flatten([for ecs_service in try(local.resources_by_type.ecs_services, []) : try(ecs_service.network_configuration.security_groups, [])]),
      flatten([for launch_template in try(local.resources_by_type.ec2_launch_templates, []) : try(launch_template.vpc_security_groups, try(launch_template.security_groups, []))]),
      tolist(local.addon_security_group_reference_names)
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  route_table_lookup_names = toset([
    for candidate in concat(
      [for route_table in try(local.resources_by_type.route_tables, []) : try(route_table.name, null)],
      flatten([for endpoint in try(local.resources_by_type.vpc_endpoints, []) : try(endpoint.route_tables, [])]),
      tolist(local.addon_route_table_reference_names)
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  nat_gateway_lookup_names = toset([
    for candidate in concat(
      [for nat_gateway in try(local.resources_by_type.nat_gateways, []) : try(nat_gateway.name, null)],
      flatten([
        for route_table in try(local.resources_by_type.route_tables, []) : [
          for route in try(route_table.routes, []) :
          try(route.target.value, null)
          if try(route.target.type, "") == "nat-gateway"
        ]
      ]),
      tolist(local.addon_nat_gateway_reference_names)
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  internet_gateway_lookup_names = toset([
    for candidate in concat(
      [for internet_gateway in try(local.resources_by_type.internet_gateways, []) : try(internet_gateway.name, null)],
      flatten([
        for route_table in try(local.resources_by_type.route_tables, []) : [
          for route in try(route_table.routes, []) :
          try(route.target.value, null)
          if try(route.target.type, "") == "internet-gateway"
        ]
      ]),
      tolist(local.addon_internet_gateway_reference_names)
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  iam_roles_defined = toset([
    for iam_role in try(local.resources_by_type.iam_roles, []) :
    iam_role.name
  ])

  iam_role_lookup_names = toset([
    for candidate in concat(
      [for cluster in try(local.resources_by_type.eks_clusters, []) : try(cluster.iam.cluster_role_name, null)],
      [for node_group in try(local.resources_by_type.eks_node_groups, []) : try(node_group.iam_role_name, null)]
    ) :
    trimspace(tostring(candidate))
    if try(trimspace(tostring(candidate)) != "", false)
  ])

  existing_vpc_lookup_names = toset([
    for name in setsubtract(local.vpc_lookup_names, toset(keys(local.vpcs))) :
    name
    if length(regexall("^vpc-[0-9a-f]+$", lower(name))) == 0 && length(regexall("^\\$\\{", name)) == 0
  ])

  existing_subnet_lookup_names = toset([
    for name in setsubtract(local.subnet_lookup_names, toset(keys(local.subnets))) :
    name
    if length(regexall("^subnet-[0-9a-f]+$", lower(name))) == 0 && length(regexall("^\\$\\{", name)) == 0
  ])

  existing_security_group_lookup_names = toset([
    for name in setsubtract(local.security_group_lookup_names, toset(keys(local.security_groups))) :
    name
    if length(regexall("^sg-[0-9a-f]+$", lower(name))) == 0 && length(regexall("^\\$\\{", name)) == 0
  ])

  existing_route_table_lookup_names = toset([
    for name in setsubtract(local.route_table_lookup_names, toset(keys(local.route_tables))) :
    name
    if length(regexall("^rtb-[0-9a-f]+$", lower(name))) == 0 && length(regexall("^\\$\\{", name)) == 0
  ])

  existing_nat_gateway_lookup_names = toset([
    for name in setsubtract(local.nat_gateway_lookup_names, toset(keys(local.nat_gateways))) :
    name
    if length(regexall("^nat-[0-9a-f]+$", lower(name))) == 0 && length(regexall("^\\$\\{", name)) == 0
  ])

  existing_internet_gateway_lookup_names = toset([
    for name in setsubtract(local.internet_gateway_lookup_names, toset(keys(local.internet_gateways))) :
    name
    if length(regexall("^igw-[0-9a-f]+$", lower(name))) == 0 && length(regexall("^\\$\\{", name)) == 0
  ])

  existing_iam_role_lookup_names = toset([
    for name in setsubtract(local.iam_role_lookup_names, local.iam_roles_defined) :
    name
    if length(regexall("^arn:", lower(name))) == 0
  ])

  existing_vpc_ids_by_name = {
    for name, existing_vpc in data.aws_vpc.existing_by_name :
    name => existing_vpc.id
  }

  existing_subnet_ids_by_name = {
    for name, existing_subnet in data.aws_subnet.existing_by_name :
    name => existing_subnet.id
  }

  existing_internet_gateway_ids_by_name = {
    for name, existing_internet_gateway in data.aws_internet_gateway.existing_by_name :
    name => existing_internet_gateway.id
  }

  existing_nat_gateway_ids_by_name = {
    for name, existing_nat_gateway in data.aws_nat_gateway.existing_by_name :
    name => existing_nat_gateway.id
  }

  existing_route_table_ids_by_name = {
    for name, existing_route_table in data.aws_route_table.existing_by_name :
    name => existing_route_table.id
  }

  existing_security_group_ids_by_name = {
    for name, existing_security_group in data.aws_security_group.existing_by_name :
    name => existing_security_group.id
  }

  existing_iam_role_arns_by_name = {
    for name, existing_iam_role in data.aws_iam_role.existing_by_name :
    name => existing_iam_role.arn
  }

  vpc_ids_by_name = merge(local.existing_vpc_ids_by_name, {
    for name, mod in module.vpcs :
    name => mod.id
  })

  subnet_ids_by_name = merge(local.existing_subnet_ids_by_name, {
    for name, mod in module.subnets :
    name => mod.id
  })

  internet_gateway_ids_by_name = merge(local.existing_internet_gateway_ids_by_name, {
    for name, mod in module.internet_gateways :
    name => mod.id
  })

  nat_gateway_ids_by_name = merge(local.existing_nat_gateway_ids_by_name, {
    for name, mod in module.nat_gateways :
    name => mod.id
  })

  route_table_ids_by_name = merge(local.existing_route_table_ids_by_name, {
    for name, mod in module.route_tables :
    name => mod.id
  })

  eks_cluster_arns_by_name = {
    for name, mod in module.eks_clusters :
    name => mod.arn
  }

  launch_templates_referencing_cluster_context = anytrue(flatten([
    for launch_template in try(local.resources_by_type.ec2_launch_templates, []) : [
      for security_group in try(launch_template.vpc_security_groups, try(launch_template.security_groups, [])) :
      length(regexall("\\$\\{\\s*(cluster|eks_cluster)\\[", tostring(security_group))) > 0
    ]
  ]))

  eks_cluster_attributes_by_name = local.launch_templates_referencing_cluster_context ? {
    for name, mod in module.eks_clusters :
    name => {
      name              = mod.name
      arn               = mod.arn
      endpoint          = mod.endpoint
      version           = mod.version
      security_group_id = mod.cluster_security_group_id
    }
  } : {}

  eks_node_group_arns_by_name = {
    for name, mod in module.eks_node_groups :
    name => mod.arn
  }

  eks_addon_arns_by_key = {
    for name, mod in module.eks_addons :
    name => mod.arn
  }

  security_group_ids_by_name = merge(local.existing_security_group_ids_by_name, {
    for name, mod in module.security_groups :
    name => mod.id
  })

  iam_role_arns_by_name = merge(local.existing_iam_role_arns_by_name, module.network_identity.iam_role_arns_by_name)

  managed_iam_role_names = toset(keys(local.iam_role_arns_by_name))

  security_group_inbound_rules = flatten([
    for security_group_name, security_group in local.security_groups : [
      for rule in try(security_group.inbound_rules, []) : {
        security_group_name = security_group_name
        description         = try(rule.description, null)
        protocol            = try(rule.protocol, "tcp")
        from_port           = try(tonumber(rule.port_range.from), try(tonumber(rule.port_range), 0))
        to_port             = try(tonumber(rule.port_range.to), try(tonumber(rule.port_range), 0))
        peer_type           = try(rule.source.type, "ip")
        peer_value          = try(rule.source.value, "0.0.0.0/0")
      }
    ]
  ])

  security_group_outbound_rules = flatten([
    for security_group_name, security_group in local.security_groups : [
      for rule in try(security_group.outbound_rules, []) : {
        security_group_name = security_group_name
        description         = try(rule.description, null)
        protocol            = try(rule.protocol, "tcp")
        from_port           = try(tonumber(rule.port_range.from), try(tonumber(rule.port_range), 0))
        to_port             = try(tonumber(rule.port_range.to), try(tonumber(rule.port_range), 0))
        peer_type           = try(rule.destination.type, "ip")
        peer_value          = try(rule.destination.value, "0.0.0.0/0")
      }
    ]
  ])

  security_group_inbound_rules_by_key = {
    for rule in local.security_group_inbound_rules :
    format(
      "%s:inbound:%s",
      rule.security_group_name,
      sha1(jsonencode({
        protocol   = rule.protocol
        from_port  = rule.from_port
        to_port    = rule.to_port
        peer_type  = rule.peer_type
        peer_value = rule.peer_value
      }))
    ) => rule
  }

  security_group_outbound_rules_by_key = {
    for rule in local.security_group_outbound_rules :
    format(
      "%s:outbound:%s",
      rule.security_group_name,
      sha1(jsonencode({
        protocol   = rule.protocol
        from_port  = rule.from_port
        to_port    = rule.to_port
        peer_type  = rule.peer_type
        peer_value = rule.peer_value
      }))
    ) => rule
  }

  ec2_launch_template_names_by_key = try(module.compute_storage.ec2_launch_template_names_by_key, {})

  eks_clusters = {
    for cluster in try(local.resources_by_type.eks_clusters, []) :
    cluster.name => merge(cluster, {
      subnet_ids = [
        for subnet in cluster.subnet_ids :
        lookup(local.subnet_ids_by_name, subnet, subnet)
      ]
      security_groups = [
        for security_group in try(cluster.security_groups, []) :
        lookup(local.security_group_ids_by_name, security_group, security_group)
      ]
      iam = merge(
        try(cluster.iam, {}),
        {
          cluster_role_arn = (
            try(trimspace(cluster.iam.cluster_role_arn), "") != "" ?
            cluster.iam.cluster_role_arn :
            lookup(local.iam_role_arns_by_name, try(cluster.iam.cluster_role_name, ""), null)
          )
          cluster_role_name = (
            try(trimspace(cluster.iam.cluster_role_arn) != "", false) ||
            contains(local.managed_iam_role_names, try(cluster.iam.cluster_role_name, ""))
          ) ? null : try(cluster.iam.cluster_role_name, null)
        }
      )
    })
  }

  eks_node_groups = {
    for node_group in try(local.resources_by_type.eks_node_groups, []) :
    node_group.name => merge(node_group, {
      subnet_ids = [
        for subnet in node_group.subnet_ids :
        lookup(local.subnet_ids_by_name, subnet, subnet)
      ]
      iam_role_arn = (
        try(trimspace(node_group.iam_role_arn), "") != "" ?
        node_group.iam_role_arn :
        lookup(local.iam_role_arns_by_name, try(node_group.iam_role_name, ""), null)
      )
      iam_role_name = (
        try(trimspace(node_group.iam_role_arn) != "", false) ||
        contains(local.managed_iam_role_names, try(node_group.iam_role_name, ""))
      ) ? null : try(node_group.iam_role_name, null)
      launch_template = try(node_group.launch_template, null) == null ? null : merge(
        node_group.launch_template,
        {
          name = lookup(
            local.ec2_launch_template_names_by_key,
            try(node_group.launch_template.name, ""),
            try(node_group.launch_template.name, null)
          )
          version = try(node_group.launch_template.version, "$Latest")
        }
      )
      remote_access = try(node_group.remote_access, null) == null ? null : merge(
        node_group.remote_access,
        {
          source_security_groups = [
            for security_group in try(node_group.remote_access.source_security_groups, []) :
            lookup(local.security_group_ids_by_name, security_group, security_group)
          ]
        }
      )
    })
  }

  eks_addons = {
    for addon in try(local.resources_by_type.eks_addons, []) :
    "${addon.cluster}:${addon.name}" => merge(addon, {
      configuration_values = try(addon.configuration_values, null) == null ? null : templatestring(
        addon.configuration_values,
        {
          subnet           = local.subnet_ids_by_name
          security_group   = local.security_group_ids_by_name
          vpc              = local.vpc_ids_by_name
          route_table      = local.route_table_ids_by_name
          nat_gateway      = local.nat_gateway_ids_by_name
          internet_gateway = local.internet_gateway_ids_by_name
          cluster = {
            for name, mod in module.eks_clusters :
            name => {
              name              = mod.name
              arn               = mod.arn
              endpoint          = mod.endpoint
              version           = mod.version
              security_group_id = mod.cluster_security_group_id
            }
          }
          eks_cluster = {
            for name, mod in module.eks_clusters :
            name => {
              name              = mod.name
              arn               = mod.arn
              endpoint          = mod.endpoint
              version           = mod.version
              security_group_id = mod.cluster_security_group_id
            }
          }
        }
      )
    })
  }
}

check "project_managed_by_is_set" {
  assert {
    condition     = local.project_managed_by != ""
    error_message = "spec.yaml project.managed_by must be set to apply global ownership tags."
  }
}

check "project_environment_is_set" {
  assert {
    condition     = local.project_environment != ""
    error_message = "spec.yaml project.environment must be set to apply the global environment tag."
  }
}

check "project_maintainer_is_set" {
  assert {
    condition     = local.project_maintainer != ""
    error_message = "spec.yaml project.maintainer must be set to apply global ownership tags."
  }
}

provider "aws" {
  region  = local.project.region
  profile = try(local.project.profile, null)

  default_tags {
    tags = local.project_global_tags
  }
}

data "aws_vpc" "existing_by_name" {
  for_each = local.existing_vpc_lookup_names

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_subnet" "existing_by_name" {
  for_each = local.existing_subnet_lookup_names

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_internet_gateway" "existing_by_name" {
  for_each = local.existing_internet_gateway_lookup_names

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_nat_gateway" "existing_by_name" {
  for_each = local.existing_nat_gateway_lookup_names

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_route_table" "existing_by_name" {
  for_each = local.existing_route_table_lookup_names

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_security_group" "existing_by_name" {
  for_each = local.existing_security_group_lookup_names
  name     = each.value
}

data "aws_iam_role" "existing_by_name" {
  for_each = local.existing_iam_role_lookup_names
  name     = each.value
}

module "vpcs" {
  source   = "./modules/vpc"
  for_each = local.vpcs

  name                   = each.value.name
  cidr                   = each.value.cidr
  additional_cidr_blocks = try(each.value.additional_cidr_blocks, [])
  tags                   = try(each.value.tags, {})

  enable_dns_support               = try(each.value.enable_dns_support, true)
  enable_dns_hostnames             = try(each.value.enable_dns_hostnames, true)
  instance_tenancy                 = try(each.value.instance_tenancy, "default")
  assign_generated_ipv6_cidr_block = try(each.value.assign_generated_ipv6_cidr_block, false)
}

module "subnets" {
  source   = "./modules/subnet"
  for_each = local.subnets

  name                            = each.value.name
  vpc_id                          = lookup(local.vpc_ids_by_name, each.value.vpc, each.value.vpc)
  cidr_block                      = each.value.cidr
  availability_zone               = try(each.value.availability_zone, null)
  map_public_ip_on_launch         = try(each.value.map_public_ip_on_launch, false)
  assign_ipv6_address_on_creation = try(each.value.assign_ipv6_address_on_creation, false)
  tags                            = try(each.value.tags, {})

  depends_on = [module.vpcs]
}

module "internet_gateways" {
  source   = "./modules/internet-gateway"
  for_each = local.internet_gateways

  name   = each.value.name
  vpc_id = lookup(local.vpc_ids_by_name, each.value.vpc, each.value.vpc)
  tags   = try(each.value.tags, {})

  depends_on = [module.vpcs]
}

module "nat_gateways" {
  source   = "./modules/nat-gateway"
  for_each = local.nat_gateways

  name            = each.value.name
  subnet_id       = lookup(local.subnet_ids_by_name, each.value.subnet, each.value.subnet)
  connection_type = try(each.value.connection_type, "public")
  allocation_id   = try(each.value.allocation_id, null)
  tags            = try(each.value.tags, {})

  depends_on = [module.subnets]
}

module "route_tables" {
  source   = "./modules/route-table"
  for_each = local.route_tables

  name   = each.value.name
  vpc_id = lookup(local.vpc_ids_by_name, each.value.vpc, each.value.vpc)

  associated_subnet_ids = {
    for subnet in try(each.value.associated_subnets, []) :
    subnet => lookup(local.subnet_ids_by_name, subnet, subnet)
  }

  routes = [
    for route in try(each.value.routes, []) : {
      destination_type  = try(route.destination.type, "cidr")
      destination_value = try(route.destination.value, null)
      target_type       = try(route.target.type, null)
      target_id = (
        try(route.target.type, "") == "internet-gateway" ?
        lookup(local.internet_gateway_ids_by_name, try(route.target.value, ""), try(route.target.value, null)) :
        try(route.target.type, "") == "nat-gateway" ?
        lookup(local.nat_gateway_ids_by_name, try(route.target.value, ""), try(route.target.value, null)) :
        try(route.target.value, null)
      )
    }
  ]

  tags = try(each.value.tags, {})

  depends_on = [module.subnets, module.internet_gateways, module.nat_gateways]
}

module "security_groups" {
  source   = "./modules/security-group"
  for_each = local.security_groups

  name                   = each.value.name
  vpc_id                 = lookup(local.vpc_ids_by_name, each.value.vpc, each.value.vpc)
  revoke_rules_on_delete = try(each.value.revoke_rules_on_delete, false)

  tags = try(each.value.tags, {})

  depends_on = [module.vpcs]
}

resource "aws_vpc_security_group_ingress_rule" "managed" {
  for_each = local.security_group_inbound_rules_by_key

  security_group_id = module.security_groups[each.value.security_group_name].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port

  cidr_ipv4 = each.value.peer_type == "ip" ? each.value.peer_value : null
  cidr_ipv6 = each.value.peer_type == "ipv6" ? each.value.peer_value : null

  prefix_list_id = each.value.peer_type == "prefix-list" ? each.value.peer_value : null

  referenced_security_group_id = each.value.peer_type == "security-group" ? (
    contains(local.security_group_names, each.value.peer_value) ?
    module.security_groups[each.value.peer_value].id :
    each.value.peer_value
    ) : each.value.peer_type == "self" ? (
    module.security_groups[each.value.security_group_name].id
  ) : null
}

resource "aws_vpc_security_group_egress_rule" "managed" {
  for_each = local.security_group_outbound_rules_by_key

  security_group_id = module.security_groups[each.value.security_group_name].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port

  cidr_ipv4 = each.value.peer_type == "ip" ? each.value.peer_value : null
  cidr_ipv6 = each.value.peer_type == "ipv6" ? each.value.peer_value : null

  prefix_list_id = each.value.peer_type == "prefix-list" ? each.value.peer_value : null

  referenced_security_group_id = each.value.peer_type == "security-group" ? (
    contains(local.security_group_names, each.value.peer_value) ?
    module.security_groups[each.value.peer_value].id :
    each.value.peer_value
    ) : each.value.peer_type == "self" ? (
    module.security_groups[each.value.security_group_name].id
  ) : null
}

module "eks_clusters" {
  source   = "./modules/eks-cluster"
  for_each = local.eks_clusters

  name               = each.value.name
  kubernetes_version = each.value.kubernetes_version

  subnet_ids      = each.value.subnet_ids
  security_groups = try(each.value.security_groups, [])

  endpoint_private_access = try(each.value.endpoint_access.private, true)
  endpoint_public_access  = try(each.value.endpoint_access.public, true)
  public_access_cidrs     = try(each.value.endpoint_access.public_access_cidrs, ["0.0.0.0/0"])

  authentication_mode = try(each.value.authentication_mode, null)
  service_ipv4_cidr   = try(each.value.service_ipv4_cidr, null)
  ip_family           = try(each.value.ip_family, null)

  cluster_logging_enabled_types = try(each.value.cluster_logging.enabled_types, [])
  cluster_log_retention_days    = try(each.value.cluster_logging.log_retention_days, 30)

  encryption_enabled     = try(each.value.encryption.enabled, false)
  encryption_resources   = try(each.value.encryption.resources, ["secrets"])
  encryption_kms_key_arn = try(each.value.encryption.kms_key_arn, null)

  cluster_role_name = try(each.value.iam.cluster_role_name, null)
  cluster_role_arn  = try(each.value.iam.cluster_role_arn, null)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )

  depends_on = [
    module.subnets,
    module.security_groups,
    aws_vpc_security_group_ingress_rule.managed,
    aws_vpc_security_group_egress_rule.managed
  ]
}

module "eks_node_groups" {
  source   = "./modules/eks-node-group"
  for_each = local.eks_node_groups

  name         = each.value.name
  cluster_name = each.value.cluster
  subnet_ids   = each.value.subnet_ids

  node_role_name = try(each.value.iam_role_name, null)
  node_role_arn  = try(each.value.iam_role_arn, null)

  ami_type       = try(each.value.ami_type, null)
  capacity_type  = try(each.value.capacity_type, "ON_DEMAND")
  instance_types = try(each.value.instance_types, [])

  desired_size = each.value.scaling.desired_size
  min_size     = each.value.scaling.min_size
  max_size     = each.value.scaling.max_size

  disk_size       = try(each.value.disk_size, null)
  disk_encryption = try(each.value.disk_encryption, true)
  release_version = try(each.value.release_version, null)

  force_update_version = try(each.value.force_update_version, false)

  launch_template = try(each.value.launch_template, null)
  labels          = try(each.value.labels, {})
  taints          = try(each.value.taints, [])
  update_config   = try(each.value.update_config, null)
  remote_access   = try(each.value.remote_access, null)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )

  depends_on = [
    module.eks_clusters,
    module.compute_storage
  ]
}

module "eks_addons" {
  source   = "./modules/eks-addon"
  for_each = local.eks_addons

  cluster_name = each.value.cluster
  addon_name   = each.value.name

  addon_version = try(each.value.version, "latest")

  resolve_conflicts_on_create = try(each.value.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(each.value.resolve_conflicts_on_update, "PRESERVE")

  service_account_role_arn = try(each.value.service_account_role_arn, null)
  configuration_values     = try(each.value.configuration_values, null)
  preserve                 = try(each.value.preserve, false)

  depends_on = [
    module.eks_clusters,
    module.eks_node_groups
  ]
}
