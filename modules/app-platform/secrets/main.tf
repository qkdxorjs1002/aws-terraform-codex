locals {
  secrets_manager_secrets = {
    for secret in try(var.resources_by_type.secrets_manager_secrets, []) :
    secret.name => secret
  }
}

resource "aws_secretsmanager_secret" "managed" {
  for_each = local.secrets_manager_secrets

  name                    = each.value.name
  description             = try(each.value.description, null)
  kms_key_id              = try(each.value.kms_key_id, null)
  recovery_window_in_days = try(each.value.recovery_window_in_days, 30)

  dynamic "replica" {
    for_each = try(each.value.replica_regions, [])

    content {
      region = replica.value
    }
  }

  tags = try(each.value.tags, {})
}

resource "aws_secretsmanager_secret_version" "managed" {
  for_each = local.secrets_manager_secrets

  secret_id     = aws_secretsmanager_secret.managed[each.key].id
  secret_string = try(each.value.secret_string, "{}")
}

resource "aws_secretsmanager_secret_rotation" "managed" {
  for_each = {
    for name, secret in local.secrets_manager_secrets :
    name => secret if try(secret.rotation_enabled, false)
  }

  secret_id           = aws_secretsmanager_secret.managed[each.key].id
  rotation_lambda_arn = each.value.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = try(each.value.rotation_rules.automatically_after_days, 30)
  }
}
