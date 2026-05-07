locals {
  efs_file_systems = {
    for file_system in try(var.resources_by_type.efs_file_systems, []) :
    file_system.name => file_system
  }

  efs_mount_targets = {
    for mount_target in flatten([
      for file_system_name, file_system in local.efs_file_systems : [
        for idx, target in try(file_system.mount_targets, []) : {
          key              = "${file_system_name}:${idx}"
          file_system_name = file_system_name
          target           = target
          subnet_ref = try(coalesce(
            try(target.subnet_id, null),
            try(target.subnet_name, null),
            try(target.subnet, null)
          ), "")
          security_group_ids = [
            for security_group in distinct(compact(concat(
              try(target.security_group_ids, []),
              try(target.security_group_names, []),
              try(target.security_groups, [])
            ))) :
            lookup(var.security_group_ids_by_name, security_group, security_group)
          ]
        }
      ]
    ]) :
    mount_target.key => mount_target
  }

  efs_access_points = {
    for access_point in flatten([
      for file_system_name, file_system in local.efs_file_systems : [
        for idx, point in try(file_system.access_points, []) : {
          key              = "${file_system_name}:${try(point.name, idx)}"
          file_system_name = file_system_name
          point            = point
        }
      ]
    ]) :
    access_point.key => access_point
  }
}

resource "aws_efs_file_system" "managed" {
  for_each = local.efs_file_systems

  creation_token                  = try(each.value.creation_token, each.value.name)
  encrypted                       = try(each.value.encrypted, true)
  kms_key_id                      = try(each.value.kms_key_id, null)
  performance_mode                = try(each.value.performance_mode, "generalPurpose")
  throughput_mode                 = try(each.value.throughput_mode, "bursting")
  provisioned_throughput_in_mibps = try(each.value.throughput_mode, "bursting") == "provisioned" ? try(each.value.provisioned_throughput_in_mibps, null) : null
  availability_zone_name = try(coalesce(
    try(each.value.availability_zone_name, null),
    try(each.value.availability_zone, null)
  ), null)

  dynamic "lifecycle_policy" {
    for_each = try(each.value.lifecycle_policies, null) != null ? each.value.lifecycle_policies : (
      try(each.value.lifecycle_policy, null) != null ? [each.value.lifecycle_policy] : []
    )

    content {
      transition_to_ia                    = try(lifecycle_policy.value.transition_to_ia, null)
      transition_to_primary_storage_class = try(lifecycle_policy.value.transition_to_primary_storage_class, null)
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )

  lifecycle {
    precondition {
      condition     = lower(try(each.value.throughput_mode, "bursting")) != "provisioned" || try(each.value.provisioned_throughput_in_mibps, null) != null
      error_message = "efs_file_systems[].provisioned_throughput_in_mibps is required when throughput_mode is provisioned."
    }
  }
}

resource "aws_efs_backup_policy" "managed" {
  for_each = {
    for name, file_system in local.efs_file_systems :
    name => file_system
    if try(file_system.backup_policy, null) != null || try(file_system.backup, null) != null
  }

  file_system_id = aws_efs_file_system.managed[each.key].id

  backup_policy {
    status = try(each.value.backup_policy.enabled, try(each.value.backup.enabled, true)) ? "ENABLED" : "DISABLED"
  }
}

resource "aws_efs_mount_target" "managed" {
  for_each = local.efs_mount_targets

  file_system_id  = aws_efs_file_system.managed[each.value.file_system_name].id
  subnet_id       = lookup(var.subnet_ids_by_name, each.value.subnet_ref, each.value.subnet_ref)
  ip_address      = try(each.value.target.ip_address, null)
  security_groups = length(each.value.security_group_ids) > 0 ? each.value.security_group_ids : null

  lifecycle {
    precondition {
      condition     = trimspace(tostring(each.value.subnet_ref)) != ""
      error_message = "efs_file_systems[].mount_targets[] requires one of subnet, subnet_name, or subnet_id."
    }
  }
}

resource "aws_efs_access_point" "managed" {
  for_each = local.efs_access_points

  file_system_id = aws_efs_file_system.managed[each.value.file_system_name].id

  dynamic "posix_user" {
    for_each = try(each.value.point.posix_user, null) == null ? [] : [each.value.point.posix_user]

    content {
      gid            = try(posix_user.value.gid, null)
      uid            = try(posix_user.value.uid, null)
      secondary_gids = try(posix_user.value.secondary_gids, null)
    }
  }

  dynamic "root_directory" {
    for_each = try(each.value.point.root_directory, null) == null ? [] : [each.value.point.root_directory]

    content {
      path = try(root_directory.value.path, "/")

      dynamic "creation_info" {
        for_each = try(root_directory.value.creation_info, null) == null ? [] : [root_directory.value.creation_info]

        content {
          owner_gid   = try(creation_info.value.owner_gid, null)
          owner_uid   = try(creation_info.value.owner_uid, null)
          permissions = try(creation_info.value.permissions, null)
        }
      }
    }
  }

  tags = merge(
    {
      Name = try(each.value.point.name, each.key)
    },
    try(each.value.point.tags, {})
  )

  lifecycle {
    precondition {
      condition = (
        try(each.value.point.posix_user, null) == null ||
        (
          try(each.value.point.posix_user.uid, null) != null &&
          try(each.value.point.posix_user.gid, null) != null
        )
      )
      error_message = "efs_file_systems[].access_points[].posix_user requires uid and gid when posix_user is set."
    }

    precondition {
      condition = (
        try(each.value.point.root_directory.creation_info, null) == null ||
        (
          try(each.value.point.root_directory.creation_info.owner_uid, null) != null &&
          try(each.value.point.root_directory.creation_info.owner_gid, null) != null &&
          try(each.value.point.root_directory.creation_info.permissions, null) != null
        )
      )
      error_message = "efs_file_systems[].access_points[].root_directory.creation_info requires owner_uid, owner_gid, and permissions when creation_info is set."
    }
  }
}
