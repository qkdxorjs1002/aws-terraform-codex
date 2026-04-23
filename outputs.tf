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

output "iam_roles" {
  description = "Created IAM roles"
  value       = module.network_identity.iam_role_arns_by_name
}

output "iam_users" {
  description = "Created IAM users"
  value       = module.network_identity.iam_user_arns_by_name
}

output "iam_groups" {
  description = "Created IAM groups"
  value       = module.network_identity.iam_group_arns_by_name
}

output "iam_policies" {
  description = "Created IAM policies"
  value       = module.network_identity.iam_policy_arns_by_name
}

output "iam_oidc_providers" {
  description = "Created IAM OIDC providers"
  value       = module.network_identity.iam_oidc_provider_arns_by_key
}

output "codedeploy_applications" {
  description = "Created CodeDeploy applications"
  value       = module.compute_storage.codedeploy_application_arns_by_name
}

output "codedeploy_deployment_groups" {
  description = "Created CodeDeploy deployment groups"
  value       = module.compute_storage.codedeploy_deployment_group_names_by_key
}

output "acm_certificates" {
  description = "Created ACM certificates keyed by domain name"
  value       = module.app_platform.acm_certificate_arns_by_domain_name
}

output "acm_certificates_regional" {
  description = "Regional ACM certificates (project region) keyed by logical certificate name"
  value       = module.app_platform.acm_regional_certificate_arns_by_domain_name
}

output "acm_certificates_us_east_1" {
  description = "CloudFront ACM certificates (us-east-1) keyed by logical certificate name"
  value       = module.app_platform.acm_us_east_1_certificate_arns_by_domain_name
}
