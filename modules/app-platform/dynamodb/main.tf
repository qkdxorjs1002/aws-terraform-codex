locals {
  dynamodb_tables = {
    for table in try(var.resources_by_type.dynamodb_tables, []) :
    table.name => table
  }
}

resource "aws_dynamodb_table" "managed" {
  for_each = local.dynamodb_tables

  name         = each.value.name
  billing_mode = try(each.value.billing_mode, "PAY_PER_REQUEST")
  hash_key     = each.value.hash_key
  range_key    = try(each.value.range_key, null)
  table_class  = try(each.value.table_class, "STANDARD")

  dynamic "attribute" {
    for_each = try(each.value.attributes, [])

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = try(each.value.global_secondary_indexes, [])

    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = try(global_secondary_index.value.range_key, null)
      projection_type    = try(global_secondary_index.value.projection_type, "ALL")
      non_key_attributes = try(global_secondary_index.value.non_key_attributes, null)
      read_capacity      = try(each.value.billing_mode, "PAY_PER_REQUEST") == "PROVISIONED" ? try(global_secondary_index.value.read_capacity, 5) : null
      write_capacity     = try(each.value.billing_mode, "PAY_PER_REQUEST") == "PROVISIONED" ? try(global_secondary_index.value.write_capacity, 5) : null
    }
  }

  dynamic "local_secondary_index" {
    for_each = try(each.value.local_secondary_indexes, [])

    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key
      projection_type    = try(local_secondary_index.value.projection_type, "ALL")
      non_key_attributes = try(local_secondary_index.value.non_key_attributes, null)
    }
  }

  dynamic "ttl" {
    for_each = try(each.value.ttl, null) == null ? [] : [each.value.ttl]

    content {
      enabled        = try(ttl.value.enabled, true)
      attribute_name = try(ttl.value.attribute_name, "ttl")
    }
  }

  point_in_time_recovery {
    enabled = try(each.value.point_in_time_recovery, true)
  }

  stream_enabled   = try(each.value.stream_enabled, false)
  stream_view_type = try(each.value.stream_enabled, false) ? try(each.value.stream_view_type, "NEW_AND_OLD_IMAGES") : null

  dynamic "server_side_encryption" {
    for_each = try(each.value.server_side_encryption, null) == null ? [] : [each.value.server_side_encryption]

    content {
      enabled     = try(server_side_encryption.value.enabled, true)
      kms_key_arn = try(server_side_encryption.value.kms_key_arn, null)
    }
  }

  deletion_protection_enabled = try(each.value.deletion_protection_enabled, true)

  tags = try(each.value.tags, {})
}
