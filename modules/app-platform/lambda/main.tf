locals {
  lambda_functions = {
    for lambda_function in try(var.resources_by_type.lambda_functions, []) :
    lambda_function.name => lambda_function
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${each.value.name}"
  retention_in_days = try(each.value.log_retention_days, 30)
}

resource "aws_lambda_function" "managed" {
  for_each = local.lambda_functions

  function_name = each.value.name
  role          = each.value.role_arn
  package_type  = try(each.value.package_type, "Zip")

  runtime          = try(each.value.package_type, "Zip") == "Zip" ? each.value.runtime : null
  handler          = try(each.value.package_type, "Zip") == "Zip" ? each.value.handler : null
  filename         = try(each.value.package_type, "Zip") == "Zip" ? try(each.value.filename, null) : null
  source_code_hash = try(each.value.source_code_hash, null)
  image_uri        = try(each.value.package_type, "Zip") == "Image" ? try(each.value.image_uri, null) : null

  timeout                        = try(each.value.timeout, 30)
  memory_size                    = try(each.value.memory_size, 512)
  publish                        = try(each.value.publish, false)
  reserved_concurrent_executions = try(each.value.reserved_concurrent_executions, -1)
  architectures                  = try(each.value.architectures, ["x86_64"])
  layers                         = try(each.value.layers, null)
  kms_key_arn                    = try(each.value.kms_key_arn, null)

  dynamic "ephemeral_storage" {
    for_each = try(each.value.ephemeral_storage_mb, null) == null ? [] : [1]

    content {
      size = each.value.ephemeral_storage_mb
    }
  }

  dynamic "vpc_config" {
    for_each = length(concat(
      try(each.value.vpc_config.subnet_ids, []),
      try(each.value.vpc_config.subnet_names, [])
    )) > 0 ? [each.value.vpc_config] : []

    content {
      subnet_ids = [
        for subnet in distinct(compact(concat(
          try(vpc_config.value.subnet_ids, []),
          try(vpc_config.value.subnet_names, [])
        ))) :
        lookup(var.subnet_ids_by_name, subnet, subnet)
      ]
      security_group_ids = [
        for security_group in distinct(compact(concat(
          try(vpc_config.value.security_group_ids, []),
          try(vpc_config.value.security_group_names, [])
        ))) :
        lookup(var.security_group_ids_by_name, security_group, security_group)
      ]
    }
  }

  dynamic "file_system_config" {
    for_each = try(each.value.file_system_config, null) == null ? [] : [each.value.file_system_config]

    content {
      arn              = file_system_config.value.arn
      local_mount_path = file_system_config.value.local_mount_path
    }
  }

  dynamic "environment" {
    for_each = length(try(keys(each.value.environment_variables), [])) > 0 ? [1] : []

    content {
      variables = each.value.environment_variables
    }
  }

  dynamic "dead_letter_config" {
    for_each = try(each.value.dead_letter_target_arn, null) == null ? [] : [1]

    content {
      target_arn = each.value.dead_letter_target_arn
    }
  }

  tracing_config {
    mode = try(each.value.tracing_mode, "PassThrough")
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )

  depends_on = [aws_cloudwatch_log_group.lambda]
}
