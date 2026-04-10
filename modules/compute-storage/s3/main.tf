locals {
  s3_buckets = {
    for bucket in try(var.resources_by_type.s3_buckets, []) :
    bucket.name => bucket
  }
}

resource "aws_s3_bucket" "managed" {
  for_each = local.s3_buckets

  bucket        = each.value.name
  force_destroy = try(each.value.force_destroy, false)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_s3_bucket_ownership_controls" "managed" {
  for_each = local.s3_buckets

  bucket = aws_s3_bucket.managed[each.key].id

  rule {
    object_ownership = try(each.value.object_ownership, "BucketOwnerEnforced")
  }
}

resource "aws_s3_bucket_versioning" "managed" {
  for_each = local.s3_buckets

  bucket = aws_s3_bucket.managed[each.key].id

  versioning_configuration {
    status = lower(try(each.value.bucket_versioning, "enabled")) == "enabled" ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "managed" {
  for_each = local.s3_buckets

  bucket = aws_s3_bucket.managed[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = try(each.value.encryption.type, "s3-managed") == "kms" ? "aws:kms" : "AES256"
      kms_master_key_id = try(each.value.encryption.kms_key_arn, null)
    }
    bucket_key_enabled = try(each.value.bucket_key_management.enabled, false)
  }
}

resource "aws_s3_bucket_public_access_block" "managed" {
  for_each = local.s3_buckets

  bucket = aws_s3_bucket.managed[each.key].id

  block_public_acls       = try(each.value.public_access_block.block_public_acls, true)
  ignore_public_acls      = try(each.value.public_access_block.ignore_public_acls, true)
  block_public_policy     = try(each.value.public_access_block.block_public_policy, true)
  restrict_public_buckets = try(each.value.public_access_block.restrict_public_buckets, true)
}

resource "aws_s3_bucket_lifecycle_configuration" "managed" {
  for_each = {
    for name, bucket in local.s3_buckets :
    name => bucket if length(try(bucket.lifecycle_rules, [])) > 0
  }

  bucket = aws_s3_bucket.managed[each.key].id

  dynamic "rule" {
    for_each = try(each.value.lifecycle_rules, [])

    content {
      id     = try(rule.value.id, "default")
      status = try(rule.value.enabled, true) ? "Enabled" : "Disabled"

      filter {
        prefix = try(rule.value.prefix, "")
      }

      dynamic "transition" {
        for_each = try(rule.value.transitions, [])

        content {
          days          = try(transition.value.days, null)
          storage_class = transition.value.storage_class
        }
      }

      expiration {
        days = try(rule.value.expiration_days, null)
      }
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "managed" {
  for_each = {
    for name, bucket in local.s3_buckets :
    name => bucket if length(try(bucket.cors_rules, [])) > 0
  }

  bucket = aws_s3_bucket.managed[each.key].id

  dynamic "cors_rule" {
    for_each = try(each.value.cors_rules, [])

    content {
      allowed_methods = try(cors_rule.value.allowed_methods, ["GET"])
      allowed_origins = try(cors_rule.value.allowed_origins, ["*"])
      allowed_headers = try(cors_rule.value.allowed_headers, ["*"])
      expose_headers  = try(cors_rule.value.expose_headers, [])
      max_age_seconds = try(cors_rule.value.max_age_seconds, null)
    }
  }
}

resource "aws_s3_bucket_logging" "managed" {
  for_each = {
    for name, bucket in local.s3_buckets :
    name => bucket if try(bucket.logging.enabled, false)
  }

  bucket = aws_s3_bucket.managed[each.key].id

  target_bucket = each.value.logging.target_bucket
  target_prefix = try(each.value.logging.target_prefix, null)
}
