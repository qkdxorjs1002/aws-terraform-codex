locals {
  cloudwatch_log_groups = {
    for log_group in try(var.resources_by_type.cloudwatch_log_groups, []) :
    log_group.name => log_group
  }

  cloudwatch_metric_alarms = {
    for alarm in try(var.resources_by_type.cloudwatch_metric_alarms, []) :
    alarm.name => alarm
  }

  cloudwatch_dashboards = {
    for dashboard in try(var.resources_by_type.cloudwatch_dashboards, []) :
    dashboard.name => dashboard
  }
}

resource "aws_cloudwatch_log_group" "managed" {
  for_each = local.cloudwatch_log_groups

  name              = each.value.name
  retention_in_days = try(each.value.retention_in_days, null)
  kms_key_id        = try(each.value.kms_key_id, null)
  skip_destroy      = try(each.value.skip_destroy, false)
  log_group_class   = try(each.value.log_group_class, null)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_cloudwatch_metric_alarm" "managed" {
  for_each = local.cloudwatch_metric_alarms

  alarm_name                = each.value.name
  alarm_description         = try(each.value.alarm_description, null)
  namespace                 = each.value.namespace
  metric_name               = each.value.metric_name
  statistic                 = try(each.value.statistic, null)
  period                    = try(each.value.period, 300)
  evaluation_periods        = try(each.value.evaluation_periods, 1)
  datapoints_to_alarm       = try(each.value.datapoints_to_alarm, null)
  threshold                 = each.value.threshold
  comparison_operator       = each.value.comparison_operator
  treat_missing_data        = try(each.value.treat_missing_data, "missing")
  dimensions                = try(each.value.dimensions, null)
  unit                      = try(each.value.unit, null)
  alarm_actions             = try(each.value.alarm_actions, [])
  ok_actions                = try(each.value.ok_actions, [])
  insufficient_data_actions = try(each.value.insufficient_data_actions, [])
}

resource "aws_cloudwatch_dashboard" "managed" {
  for_each = local.cloudwatch_dashboards

  dashboard_name = each.value.name
  dashboard_body = jsonencode({
    widgets = try(each.value.widgets, [])
  })
}
