output "eks_clusters" {
  description = "Created EKS clusters"
  value = {
    for name, mod in module.eks_clusters :
    name => {
      arn      = mod.arn
      endpoint = mod.endpoint
      version  = mod.version
    }
  }
}

output "eks_node_groups" {
  description = "Created EKS managed node groups"
  value = {
    for name, mod in module.eks_node_groups :
    name => {
      arn    = mod.arn
      status = mod.status
    }
  }
}

output "eks_addons" {
  description = "Created EKS addons"
  value = merge(
    {
      for key, mod in module.eks_addons_pre_node_groups :
      key => {
        arn     = mod.arn
        version = mod.version
      }
    },
    {
      for key, mod in module.eks_addons_post_node_groups :
      key => {
        arn     = mod.arn
        version = mod.version
      }
    }
  )
}

output "vpcs" {
  description = "Created VPCs"
  value = {
    for name, mod in module.vpcs :
    name => {
      id         = mod.id
      arn        = mod.arn
      cidr_block = mod.cidr_block
    }
  }
}

output "subnets" {
  description = "Created subnets"
  value = {
    for name, mod in module.subnets :
    name => {
      id  = mod.id
      arn = mod.arn
    }
  }
}

output "internet_gateways" {
  description = "Created internet gateways"
  value = {
    for name, mod in module.internet_gateways :
    name => {
      id = mod.id
    }
  }
}

output "nat_gateways" {
  description = "Created NAT gateways"
  value = {
    for name, mod in module.nat_gateways :
    name => {
      id = mod.id
    }
  }
}

output "route_tables" {
  description = "Created route tables"
  value = {
    for name, mod in module.route_tables :
    name => {
      id = mod.id
    }
  }
}

output "security_groups" {
  description = "Created security groups"
  value = {
    for name, mod in module.security_groups :
    name => {
      id  = mod.id
      arn = mod.arn
    }
  }
}
