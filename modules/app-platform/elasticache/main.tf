locals {
  elasticache_replication_groups = {
    for group in try(var.resources_by_type.elasticache_replication_groups, []) :
    group.replication_group_id => group
  }
}

resource "aws_elasticache_replication_group" "managed" {
  for_each = local.elasticache_replication_groups

  replication_group_id = each.value.replication_group_id
  description          = try(each.value.description, each.value.replication_group_id)
  engine               = try(each.value.engine, "redis")
  engine_version       = try(each.value.engine_version, null)
  node_type            = each.value.node_type
  port                 = try(each.value.port, 6379)
  parameter_group_name = try(each.value.parameter_group_name, null)
  subnet_group_name    = try(each.value.subnet_group_name, null)
  security_group_ids = [
    for sg in distinct(compact(concat(
      try(each.value.security_group_ids, []),
      try(each.value.security_group_names, [])
    ))) :
    lookup(var.security_group_ids_by_name, sg, sg)
  ]
  num_cache_clusters         = try(each.value.num_cache_clusters, 2)
  automatic_failover_enabled = try(each.value.automatic_failover_enabled, true)
  multi_az_enabled           = try(each.value.multi_az_enabled, true)
  at_rest_encryption_enabled = try(each.value.at_rest_encryption_enabled, true)
  transit_encryption_enabled = try(each.value.transit_encryption_enabled, true)
  auth_token                 = try(each.value.auth_token, null)
  snapshot_retention_limit   = try(each.value.snapshot_retention_limit, 7)
  snapshot_window            = try(each.value.snapshot_window, null)
  maintenance_window         = try(each.value.maintenance_window, null)
  apply_immediately          = try(each.value.apply_immediately, false)
  auto_minor_version_upgrade = try(each.value.auto_minor_version_upgrade, true)

  tags = merge(
    {
      Name = each.value.replication_group_id
    },
    try(each.value.tags, {})
  )
}
