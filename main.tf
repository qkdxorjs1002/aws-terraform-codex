locals {
  spec = yamldecode(file("${path.module}/${var.spec_file}"))

  project = local.spec.project

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

  vpc_ids_by_name = {
    for name, mod in module.vpcs :
    name => mod.id
  }

  subnet_ids_by_name = {
    for name, mod in module.subnets :
    name => mod.id
  }

  internet_gateway_ids_by_name = {
    for name, mod in module.internet_gateways :
    name => mod.id
  }

  nat_gateway_ids_by_name = {
    for name, mod in module.nat_gateways :
    name => mod.id
  }

  route_table_ids_by_name = {
    for name, mod in module.route_tables :
    name => mod.id
  }

  eks_cluster_arns_by_name = {
    for name, mod in module.eks_clusters :
    name => mod.arn
  }

  eks_node_group_arns_by_name = {
    for name, mod in module.eks_node_groups :
    name => mod.arn
  }

  eks_addon_arns_by_key = {
    for name, mod in module.eks_addons :
    name => mod.arn
  }

  security_group_ids_by_name = {
    for name, mod in module.security_groups :
    name => mod.id
  }

  security_group_inbound_rules_using_logical_name = flatten([
    for security_group_name, security_group in local.security_groups : [
      for index, rule in try(security_group.inbound_rules, []) : {
        key                 = "${security_group_name}:inbound:${index}"
        security_group_name = security_group_name
        description         = try(rule.description, null)
        protocol            = try(rule.protocol, "tcp")
        from_port           = try(tonumber(rule.port_range.from), try(tonumber(rule.port_range), 0))
        to_port             = try(tonumber(rule.port_range.to), try(tonumber(rule.port_range), 0))
        peer_name           = try(rule.source.value, "")
      } if try(rule.source.type, "ip") == "security-group" && contains(local.security_group_names, try(rule.source.value, ""))
    ]
  ])

  security_group_outbound_rules_using_logical_name = flatten([
    for security_group_name, security_group in local.security_groups : [
      for index, rule in try(security_group.outbound_rules, []) : {
        key                 = "${security_group_name}:outbound:${index}"
        security_group_name = security_group_name
        description         = try(rule.description, null)
        protocol            = try(rule.protocol, "tcp")
        from_port           = try(tonumber(rule.port_range.from), try(tonumber(rule.port_range), 0))
        to_port             = try(tonumber(rule.port_range.to), try(tonumber(rule.port_range), 0))
        peer_name           = try(rule.destination.value, "")
      } if try(rule.destination.type, "ip") == "security-group" && contains(local.security_group_names, try(rule.destination.value, ""))
    ]
  ])

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
    })
  }

  eks_node_groups = {
    for node_group in try(local.resources_by_type.eks_node_groups, []) :
    node_group.name => merge(node_group, {
      subnet_ids = [
        for subnet in node_group.subnet_ids :
        lookup(local.subnet_ids_by_name, subnet, subnet)
      ]
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
        }
      )
    })
  }
}

provider "aws" {
  region  = local.project.region
  profile = try(local.project.profile, null)
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

  associated_subnet_ids = [
    for subnet in try(each.value.associated_subnets, []) :
    lookup(local.subnet_ids_by_name, subnet, subnet)
  ]

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

  inbound_rules = [
    for rule in try(each.value.inbound_rules, []) : {
      description = try(rule.description, null)
      protocol    = try(rule.protocol, "tcp")
      from_port   = try(tonumber(rule.port_range.from), try(tonumber(rule.port_range), 0))
      to_port     = try(tonumber(rule.port_range.to), try(tonumber(rule.port_range), 0))
      peer_type   = try(rule.source.type, "ip")
      peer_value  = try(rule.source.value, "0.0.0.0/0")
    }
    if !(try(rule.source.type, "ip") == "security-group" && contains(local.security_group_names, try(rule.source.value, "")))
  ]

  outbound_rules = [
    for rule in try(each.value.outbound_rules, []) : {
      description = try(rule.description, null)
      protocol    = try(rule.protocol, "tcp")
      from_port   = try(tonumber(rule.port_range.from), try(tonumber(rule.port_range), 0))
      to_port     = try(tonumber(rule.port_range.to), try(tonumber(rule.port_range), 0))
      peer_type   = try(rule.destination.type, "ip")
      peer_value  = try(rule.destination.value, "0.0.0.0/0")
    }
    if !(try(rule.destination.type, "ip") == "security-group" && contains(local.security_group_names, try(rule.destination.value, "")))
  ]

  tags = try(each.value.tags, {})

  depends_on = [module.vpcs]
}

resource "aws_vpc_security_group_ingress_rule" "logical_security_group_sources" {
  for_each = {
    for rule in local.security_group_inbound_rules_using_logical_name :
    rule.key => rule
  }

  security_group_id            = module.security_groups[each.value.security_group_name].id
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.protocol == "-1" ? null : each.value.from_port
  to_port                      = each.value.protocol == "-1" ? null : each.value.to_port
  referenced_security_group_id = module.security_groups[each.value.peer_name].id
}

resource "aws_vpc_security_group_egress_rule" "logical_security_group_destinations" {
  for_each = {
    for rule in local.security_group_outbound_rules_using_logical_name :
    rule.key => rule
  }

  security_group_id            = module.security_groups[each.value.security_group_name].id
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.protocol == "-1" ? null : each.value.from_port
  to_port                      = each.value.protocol == "-1" ? null : each.value.to_port
  referenced_security_group_id = module.security_groups[each.value.peer_name].id
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

  tags = try(each.value.tags, {})

  depends_on = [module.subnets, module.security_groups, module.network_identity]
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

  tags = try(each.value.tags, {})

  depends_on = [module.eks_clusters, module.network_identity]
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

  depends_on = [module.eks_clusters]
}
