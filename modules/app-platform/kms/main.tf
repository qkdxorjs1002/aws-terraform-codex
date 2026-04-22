locals {
  kms_keys = {
    for key in try(var.resources_by_type.kms_keys, []) :
    key.alias => key
  }

  kms_keys_managed = {
    for alias_name, key in local.kms_keys :
    alias_name => key
    if try(trimspace(key.existing_key_id), "") == ""
  }

  kms_aliases = {
    for alias_name, key in local.kms_keys :
    alias_name => key
    if try(key.create_alias, true)
  }
}

resource "aws_kms_key" "managed" {
  for_each = local.kms_keys_managed

  description              = try(each.value.description, each.value.alias)
  is_enabled               = try(each.value.enabled, true)
  enable_key_rotation      = try(each.value.enable_key_rotation, true)
  deletion_window_in_days  = try(each.value.deletion_window_in_days, 30)
  key_usage                = try(each.value.key_usage, "ENCRYPT_DECRYPT")
  customer_master_key_spec = try(each.value.key_spec, "SYMMETRIC_DEFAULT")
  multi_region             = try(each.value.multi_region, false)
  policy                   = try(each.value.policy, null)

  tags = merge(
    {
      Name = each.value.alias
    },
    try(each.value.tags, {})
  )
}

resource "aws_kms_alias" "managed" {
  for_each = local.kms_aliases

  name          = each.value.alias
  target_key_id = contains(keys(local.kms_keys_managed), each.key) ? aws_kms_key.managed[each.key].key_id : each.value.existing_key_id
}
