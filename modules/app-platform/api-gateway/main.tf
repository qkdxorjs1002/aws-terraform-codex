locals {
  api_gateway_http_apis = {
    for api in try(var.resources_by_type.api_gateway_http_apis, []) :
    api.name => api
  }

  api_gateway_http_integrations = {
    for integration in try(var.resources_by_type.api_gateway_http_integrations, []) :
    integration.name => integration
  }

  api_gateway_http_routes = {
    for idx, route in try(var.resources_by_type.api_gateway_http_routes, []) :
    "${route.api}:${route.route_key}:${idx}" => route
  }
}

resource "aws_apigatewayv2_api" "managed" {
  for_each = local.api_gateway_http_apis

  name                         = each.value.name
  protocol_type                = try(each.value.protocol_type, "HTTP")
  description                  = try(each.value.description, null)
  disable_execute_api_endpoint = try(each.value.disable_execute_api_endpoint, false)
  route_selection_expression   = try(each.value.route_selection_expression, null)

  dynamic "cors_configuration" {
    for_each = try(each.value.cors_configuration, null) == null ? [] : [each.value.cors_configuration]

    content {
      allow_credentials = try(cors_configuration.value.allow_credentials, false)
      allow_headers     = try(cors_configuration.value.allow_headers, [])
      allow_methods     = try(cors_configuration.value.allow_methods, [])
      allow_origins     = try(cors_configuration.value.allow_origins, [])
      expose_headers    = try(cors_configuration.value.expose_headers, [])
      max_age           = try(cors_configuration.value.max_age, null)
    }
  }

  tags = try(each.value.tags, {})
}

resource "aws_apigatewayv2_stage" "default" {
  for_each = local.api_gateway_http_apis

  api_id      = aws_apigatewayv2_api.managed[each.key].id
  name        = "$default"
  auto_deploy = try(each.value.default_stage_auto_deploy, true)

  dynamic "access_log_settings" {
    for_each = try(each.value.default_stage_access_log_settings, null) == null ? [] : [each.value.default_stage_access_log_settings]

    content {
      destination_arn = access_log_settings.value.destination_arn
      format          = access_log_settings.value.format
    }
  }

  tags = try(each.value.tags, {})
}

resource "aws_apigatewayv2_integration" "managed" {
  for_each = local.api_gateway_http_integrations

  api_id                 = lookup({ for name, api in aws_apigatewayv2_api.managed : name => api.id }, each.value.api, each.value.api)
  integration_type       = try(each.value.integration_type, "AWS_PROXY")
  integration_uri        = each.value.integration_uri
  integration_method     = try(each.value.integration_method, null)
  payload_format_version = try(each.value.payload_format_version, null)
  timeout_milliseconds   = try(each.value.timeout_milliseconds, 30000)
  connection_type        = try(each.value.connection_type, null)
  connection_id          = try(each.value.connection_id, null)
  credentials_arn        = try(each.value.credentials_arn, null)
}

resource "aws_apigatewayv2_route" "managed" {
  for_each = local.api_gateway_http_routes

  api_id    = lookup({ for name, api in aws_apigatewayv2_api.managed : name => api.id }, each.value.api, each.value.api)
  route_key = each.value.route_key
  target    = "integrations/${lookup({ for name, integration in aws_apigatewayv2_integration.managed : name => integration.id }, each.value.target_integration, each.value.target_integration)}"

  authorization_type = try(each.value.authorization_type, "NONE")
  authorizer_id      = try(each.value.authorizer_id, null)
  operation_name     = try(each.value.operation_name, null)
}
