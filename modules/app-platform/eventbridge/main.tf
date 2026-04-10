locals {
  eventbridge_buses = {
    for bus in try(var.resources_by_type.eventbridge_buses, []) :
    bus.name => bus
  }

  eventbridge_rules = {
    for rule in try(var.resources_by_type.eventbridge_rules, []) :
    rule.name => rule
  }

  eventbridge_targets = flatten([
    for rule_name, rule in local.eventbridge_rules : [
      for target in try(rule.targets, []) : {
        key            = "${rule_name}:${target.id}"
        rule_name      = rule_name
        event_bus_name = try(rule.event_bus_name, "default")
        target         = target
      }
    ]
  ])
}

resource "aws_cloudwatch_event_bus" "managed" {
  for_each = local.eventbridge_buses

  name               = each.value.name
  description        = try(each.value.description, null)
  kms_key_identifier = try(each.value.kms_key_identifier, null)

  tags = try(each.value.tags, {})
}

resource "aws_cloudwatch_event_bus_policy" "managed" {
  for_each = {
    for name, bus in local.eventbridge_buses :
    name => bus if try(bus.policy, "") != ""
  }

  event_bus_name = each.value.name
  policy         = each.value.policy
}

resource "aws_cloudwatch_event_rule" "managed" {
  for_each = local.eventbridge_rules

  name                = each.value.name
  event_bus_name      = try(each.value.event_bus_name, "default")
  description         = try(each.value.description, null)
  schedule_expression = try(each.value.schedule_expression, null)
  event_pattern       = try(each.value.event_pattern, null)
  state               = try(each.value.state, "ENABLED")
  role_arn            = try(each.value.role_arn, null)
}

resource "aws_cloudwatch_event_target" "managed" {
  for_each = {
    for target in local.eventbridge_targets :
    target.key => target
  }

  rule           = each.value.rule_name
  event_bus_name = each.value.event_bus_name
  target_id      = each.value.target.id
  arn            = each.value.target.arn
  input          = try(each.value.target.input, null)
  role_arn       = try(each.value.target.role_arn, null)

  dynamic "retry_policy" {
    for_each = try(each.value.target.retry_policy, null) == null ? [] : [each.value.target.retry_policy]

    content {
      maximum_event_age_in_seconds = try(retry_policy.value.maximum_event_age_in_seconds, null)
      maximum_retry_attempts       = try(retry_policy.value.maximum_retry_attempts, null)
    }
  }

  dynamic "dead_letter_config" {
    for_each = try(each.value.target.dead_letter_config_arn, null) == null ? [] : [1]

    content {
      arn = each.value.target.dead_letter_config_arn
    }
  }
}
