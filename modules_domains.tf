module "network_identity" {
  source = "./modules/network-identity"

  resources_by_type                    = local.resources_by_type
  vpc_ids_by_name                      = local.vpc_ids_by_name
  subnet_ids_by_name                   = local.subnet_ids_by_name
  route_table_ids_by_name              = local.route_table_ids_by_name
  security_group_ids_by_name           = local.security_group_ids_by_name
  cloudfront_distribution_arns_by_name = module.edge_containers_observability.cloudfront_distribution_arns_by_name

  depends_on = [
    module.vpcs,
    module.subnets,
    module.route_tables,
    module.security_groups
  ]
}

module "compute_storage" {
  source = "./modules/compute-storage"

  resources_by_type                       = local.resources_by_type
  vpc_ids_by_name                         = local.vpc_ids_by_name
  subnet_ids_by_name                      = local.subnet_ids_by_name
  security_group_ids_by_name              = local.security_group_ids_by_name
  iam_role_arns_by_name                   = local.iam_role_arns_by_name
  iam_instance_profile_names_by_role_name = module.network_identity.iam_instance_profile_names_by_role_name
  eks_cluster_attributes_by_name          = local.eks_cluster_attributes_by_name
  acm_certificate_arns_by_domain_name     = module.app_platform.acm_regional_certificate_arns_by_domain_name

  depends_on = [
    module.vpcs,
    module.subnets,
    module.security_groups,
    module.internet_gateways,
    module.nat_gateways,
    module.route_tables
  ]
}

module "eks_extended" {
  source = "./modules/eks-extended"

  resources_by_type              = local.resources_by_type
  region                         = local.project.region
  profile                        = try(local.project.profile, null)
  vpc_ids_by_name                = local.vpc_ids_by_name
  subnet_ids_by_name             = local.subnet_ids_by_name
  route_table_ids_by_name        = local.route_table_ids_by_name
  security_group_ids_by_name     = local.security_group_ids_by_name
  nat_gateway_ids_by_name        = local.nat_gateway_ids_by_name
  internet_gateway_ids_by_name   = local.internet_gateway_ids_by_name
  iam_role_arns_by_name          = local.iam_role_arns_by_name
  eks_cluster_dependency_arns    = local.eks_cluster_arns_by_name
  eks_node_group_dependency_arns = local.eks_node_group_arns_by_name
  eks_addon_dependency_arns      = local.eks_addon_arns_by_key
}

module "edge_containers_observability" {
  source = "./modules/edge-containers-observability"

  resources_by_type                       = local.resources_by_type
  subnet_ids_by_name                      = local.subnet_ids_by_name
  security_group_ids_by_name              = local.security_group_ids_by_name
  alb_dns_names_by_name                   = module.compute_storage.alb_dns_names_by_name
  s3_bucket_regional_domain_names_by_name = module.compute_storage.s3_bucket_regional_domain_names_by_name
  acm_certificate_arns_by_domain_name     = module.app_platform.acm_us_east_1_certificate_arns_by_domain_name

  depends_on = [
    module.compute_storage
  ]
}

module "app_platform" {
  source = "./modules/app-platform"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  resources_by_type          = local.resources_by_type
  vpc_ids_by_name            = local.vpc_ids_by_name
  subnet_ids_by_name         = local.subnet_ids_by_name
  security_group_ids_by_name = local.security_group_ids_by_name
}
