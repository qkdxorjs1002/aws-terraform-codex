module "network_identity" {
  source = "./modules/network-identity"

  resources_by_type          = local.resources_by_type
  vpc_ids_by_name            = local.vpc_ids_by_name
  subnet_ids_by_name         = local.subnet_ids_by_name
  route_table_ids_by_name    = local.route_table_ids_by_name
  security_group_ids_by_name = local.security_group_ids_by_name

  depends_on = [
    module.vpcs,
    module.subnets,
    module.route_tables,
    module.security_groups
  ]
}

module "compute_storage" {
  source = "./modules/compute-storage"

  resources_by_type          = local.resources_by_type
  vpc_ids_by_name            = local.vpc_ids_by_name
  subnet_ids_by_name         = local.subnet_ids_by_name
  security_group_ids_by_name = local.security_group_ids_by_name

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

  resources_by_type          = local.resources_by_type
  region                     = local.project.region
  vpc_ids_by_name            = local.vpc_ids_by_name
  subnet_ids_by_name         = local.subnet_ids_by_name
  route_table_ids_by_name    = local.route_table_ids_by_name
  security_group_ids_by_name = local.security_group_ids_by_name
  nat_gateway_ids_by_name    = local.nat_gateway_ids_by_name
  internet_gateway_ids_by_name = local.internet_gateway_ids_by_name
  iam_role_arns_by_name = module.network_identity.iam_role_arns_by_name
  eks_cluster_dependency_arns    = local.eks_cluster_arns_by_name
  eks_node_group_dependency_arns = local.eks_node_group_arns_by_name
  eks_addon_dependency_arns      = local.eks_addon_arns_by_key
}

module "edge_containers_observability" {
  source = "./modules/edge-containers-observability"

  resources_by_type          = local.resources_by_type
  subnet_ids_by_name         = local.subnet_ids_by_name
  security_group_ids_by_name = local.security_group_ids_by_name

  depends_on = [
    module.compute_storage
  ]
}

module "app_platform" {
  source = "./modules/app-platform"

  resources_by_type          = local.resources_by_type
  vpc_ids_by_name            = local.vpc_ids_by_name
  subnet_ids_by_name         = local.subnet_ids_by_name
  security_group_ids_by_name = local.security_group_ids_by_name

  depends_on = [
    module.network_identity,
    module.compute_storage,
    module.edge_containers_observability
  ]
}
