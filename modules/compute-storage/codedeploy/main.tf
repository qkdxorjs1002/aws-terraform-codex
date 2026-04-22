locals {
  codedeploy_applications = {
    for application in try(var.resources_by_type.codedeploy_applications, []) :
    application.name => application
  }

  codedeploy_deployment_groups = {
    for deployment_group in try(var.resources_by_type.codedeploy_deployment_groups, []) :
    "${try(deployment_group.application, try(deployment_group.app_name, ""))}:${deployment_group.name}" => deployment_group
  }

  codedeploy_application_names_by_key = {
    for key, application in aws_codedeploy_app.managed :
    key => application.name
  }

  codedeploy_application_reference_names_by_key = {
    for key, deployment_group in local.codedeploy_deployment_groups :
    key => trimspace(try(deployment_group.application, try(deployment_group.app_name, "")))
  }

  codedeploy_service_role_arns_by_key = {
    for key, deployment_group in local.codedeploy_deployment_groups :
    key => (
      try(trimspace(deployment_group.service_role_arn), "") != "" ?
      deployment_group.service_role_arn :
      lookup(
        var.iam_role_arns_by_name,
        try(trimspace(deployment_group.service_role_name), ""),
        try(deployment_group.service_role_name, null)
      )
    )
  }

  codedeploy_autoscaling_group_names_by_key = {
    for key, deployment_group in local.codedeploy_deployment_groups :
    key => [
      for autoscaling_group in try(deployment_group.autoscaling_groups, []) :
      (
        lookup(
          var.auto_scaling_group_names_by_key,
          trimspace(tostring(autoscaling_group)),
          trimspace(tostring(autoscaling_group))
        )
      )
    ]
  }

  codedeploy_target_group_names_by_key = {
    for key, deployment_group in local.codedeploy_deployment_groups :
    key => concat(
      [
        for target_group in try(deployment_group.load_balancer_info.target_groups, []) :
        (
          lookup(
            var.alb_target_group_names_by_key,
            trimspace(tostring(target_group)),
            trimspace(tostring(target_group))
          )
        )
      ],
      [
        for target_group in try(deployment_group.load_balancer_info.target_group_info, []) :
        (
          lookup(
            var.alb_target_group_names_by_key,
            trimspace(tostring(try(target_group.name, target_group))),
            trimspace(tostring(try(target_group.name, target_group)))
          )
        )
      ]
    )
  }

  codedeploy_ec2_tag_set_by_key = {
    for key, deployment_group in local.codedeploy_deployment_groups :
    key => [
      for tag_filter_set in try(deployment_group.ec2_tag_set, []) : [
        for tag_filter in try(tag_filter_set, []) :
        tag_filter
      ]
    ]
  }
}

resource "aws_codedeploy_app" "managed" {
  for_each = local.codedeploy_applications

  name             = each.value.name
  compute_platform = try(each.value.compute_platform, "Server")

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_codedeploy_deployment_group" "managed" {
  for_each = local.codedeploy_deployment_groups

  app_name = lookup(
    local.codedeploy_application_names_by_key,
    local.codedeploy_application_reference_names_by_key[each.key],
    local.codedeploy_application_reference_names_by_key[each.key]
  )
  deployment_group_name       = each.value.name
  service_role_arn            = local.codedeploy_service_role_arns_by_key[each.key]
  deployment_config_name      = try(each.value.deployment_config_name, null)
  autoscaling_groups          = local.codedeploy_autoscaling_group_names_by_key[each.key]
  outdated_instances_strategy = try(each.value.outdated_instances_strategy, null)

  dynamic "deployment_style" {
    for_each = try(each.value.deployment_style, null) == null ? [] : [each.value.deployment_style]

    content {
      deployment_option = try(deployment_style.value.deployment_option, "WITHOUT_TRAFFIC_CONTROL")
      deployment_type   = try(deployment_style.value.deployment_type, "IN_PLACE")
    }
  }

  dynamic "auto_rollback_configuration" {
    for_each = try(each.value.auto_rollback_configuration, null) == null ? [] : [each.value.auto_rollback_configuration]

    content {
      enabled = try(auto_rollback_configuration.value.enabled, false)
      events  = try(auto_rollback_configuration.value.events, null)
    }
  }

  dynamic "alarm_configuration" {
    for_each = try(each.value.alarm_configuration, null) == null ? [] : [each.value.alarm_configuration]

    content {
      enabled                   = try(alarm_configuration.value.enabled, false)
      ignore_poll_alarm_failure = try(alarm_configuration.value.ignore_poll_alarm_failure, false)
      alarms = [
        for alarm in try(alarm_configuration.value.alarms, []) :
        try(alarm.name, alarm)
      ]
    }
  }

  dynamic "trigger_configuration" {
    for_each = try(each.value.trigger_configurations, [])

    content {
      trigger_name       = trigger_configuration.value.trigger_name
      trigger_target_arn = trigger_configuration.value.trigger_target_arn
      trigger_events     = try(trigger_configuration.value.trigger_events, [])
    }
  }

  dynamic "ec2_tag_filter" {
    for_each = try(each.value.ec2_tag_filters, [])

    content {
      key   = try(ec2_tag_filter.value.key, null)
      type  = try(ec2_tag_filter.value.type, null)
      value = try(ec2_tag_filter.value.value, null)
    }
  }

  dynamic "ec2_tag_set" {
    for_each = local.codedeploy_ec2_tag_set_by_key[each.key]

    content {
      dynamic "ec2_tag_filter" {
        for_each = ec2_tag_set.value

        content {
          key   = try(ec2_tag_filter.value.key, null)
          type  = try(ec2_tag_filter.value.type, null)
          value = try(ec2_tag_filter.value.value, null)
        }
      }
    }
  }

  dynamic "load_balancer_info" {
    for_each = length(local.codedeploy_target_group_names_by_key[each.key]) == 0 ? [] : [1]

    content {
      dynamic "target_group_info" {
        for_each = local.codedeploy_target_group_names_by_key[each.key]

        content {
          name = target_group_info.value
        }
      }
    }
  }
}
