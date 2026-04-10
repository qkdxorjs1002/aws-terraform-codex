locals {
  rds_subnet_groups = {
    for subnet_group in try(var.resources_by_type.rds_subnet_groups, []) :
    subnet_group.name => subnet_group
  }

  rds_instances = {
    for instance in try(var.resources_by_type.rds_instances, []) :
    instance.name => instance
  }
}

resource "aws_db_subnet_group" "managed" {
  for_each = local.rds_subnet_groups

  name        = each.value.name
  description = try(each.value.description, each.value.name)
  subnet_ids = [
    for subnet in try(each.value.subnets, []) :
    lookup(var.subnet_ids_by_name, subnet, subnet)
  ]

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_db_instance" "managed" {
  for_each = local.rds_instances

  identifier     = try(each.value.identifier, each.value.name)
  engine         = each.value.engine
  engine_version = try(each.value.engine_version, null)
  instance_class = each.value.instance_type

  allocated_storage     = try(each.value.storage.allocated_storage, 20)
  max_allocated_storage = try(each.value.storage.storage_autoscaling, false) ? try(each.value.storage.max_allocated_storage, null) : null
  storage_type          = try(each.value.storage.storage_type, "gp3")
  iops                  = try(each.value.storage.iops, null)
  storage_throughput    = try(each.value.storage.storage_throughput, null)

  username = try(each.value.credential.username, null)
  password = try(each.value.credential.type, "manual") == "managed" ? null : try(each.value.credential.password, null)

  manage_master_user_password = try(each.value.credential.type, "manual") == "managed"

  iam_database_authentication_enabled = try(each.value.credential.authentication_method, "") == "password-and-iam"

  db_subnet_group_name = lookup(
    { for name, sg in aws_db_subnet_group.managed : name => sg.name },
    each.value.subnet_group,
    each.value.subnet_group
  )

  vpc_security_group_ids = [
    for security_group in try(each.value.security_groups, []) :
    lookup(var.security_group_ids_by_name, security_group, security_group)
  ]

  publicly_accessible = try(each.value.publicly_accessible, false)
  multi_az            = try(each.value.multi_az, false)
  availability_zone   = try(each.value.availability_zone, null)
  port                = try(each.value.database_port, null)

  backup_retention_period = try(each.value.backup.enabled, true) ? try(each.value.backup.retention_period, 7) : 0
  storage_encrypted       = try(each.value.backup.encrypted, true)
  backup_window           = try(each.value.backup.backup_window, null)
  maintenance_window      = try(each.value.maintenance_window, null)

  monitoring_interval = try(each.value.monitoring_interval, 0)
  monitoring_role_arn = try(each.value.monitoring_role_arn, null)

  performance_insights_enabled    = try(each.value.performance_insights_enabled, false)
  performance_insights_kms_key_id = try(each.value.performance_insights_kms_key_id, null)

  parameter_group_name = try(each.value.parameter_group_name, null)
  option_group_name    = try(each.value.option_group_name, null)

  auto_minor_version_upgrade = try(each.value.auto_minor_version_upgrade, true)
  deletion_protection        = try(each.value.enable_delete_protection, true)
  copy_tags_to_snapshot      = try(each.value.copy_tags_to_snapshot, true)

  skip_final_snapshot       = try(each.value.skip_final_snapshot, false)
  final_snapshot_identifier = try(each.value.skip_final_snapshot, false) ? null : try(each.value.final_snapshot_identifier, "${try(each.value.identifier, each.value.name)}-final")

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}
