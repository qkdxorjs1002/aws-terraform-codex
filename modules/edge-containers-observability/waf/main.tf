locals {
  waf_web_acls = {
    for acl in try(var.resources_by_type.waf_web_acls, []) :
    acl.name => acl
  }
}

resource "aws_wafv2_web_acl" "managed" {
  for_each = local.waf_web_acls

  name        = each.value.name
  description = try(each.value.description, null)
  scope       = try(each.value.scope, "REGIONAL")

  dynamic "default_action" {
    for_each = [try(each.value.default_action, "allow")]

    content {
      dynamic "allow" {
        for_each = default_action.value == "allow" ? [1] : []
        content {}
      }

      dynamic "block" {
        for_each = default_action.value == "block" ? [1] : []
        content {}
      }
    }
  }

  dynamic "rule" {
    for_each = try(each.value.managed_rule_groups, [])

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = try(rule.value.override_action, "none") == "none" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = try(rule.value.override_action, "none") == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = try(rule.value.vendor_name, "AWS")
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${try(each.value.visibility_config.metric_name, each.value.name)}-${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = try(each.value.rate_based_rules, [])

    content {
      name     = rule.value.name
      priority = rule.value.priority

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = try(rule.value.aggregate_key_type, "IP")
        }
      }

      dynamic "action" {
        for_each = [try(rule.value.action, "block")]

        content {
          dynamic "allow" {
            for_each = action.value == "allow" ? [1] : []
            content {}
          }

          dynamic "block" {
            for_each = action.value == "block" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "count" ? [1] : []
            content {}
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${try(each.value.visibility_config.metric_name, each.value.name)}-${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = try(each.value.visibility_config.cloudwatch_metrics_enabled, true)
    metric_name                = try(each.value.visibility_config.metric_name, each.value.name)
    sampled_requests_enabled   = try(each.value.visibility_config.sampled_requests_enabled, true)
  }

  tags = try(each.value.tags, {})
}
