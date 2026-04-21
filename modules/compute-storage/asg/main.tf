locals {
  ec2_auto_scaling_groups = {
    for autoscaling_group in try(var.resources_by_type.ec2_auto_scaling_groups, []) :
    autoscaling_group.name => autoscaling_group
  }

  autoscaling_group_subnet_ids = {
    for asg_name, autoscaling_group in local.ec2_auto_scaling_groups :
    asg_name => [
      for subnet in try(autoscaling_group.subnets, []) :
      lookup(var.subnet_ids_by_name, subnet, subnet)
    ]
  }

  autoscaling_group_target_group_arns = {
    for asg_name, autoscaling_group in local.ec2_auto_scaling_groups :
    asg_name => [
      for target_group in try(autoscaling_group.target_groups, []) :
      lookup(var.alb_target_group_arns_by_key, target_group, target_group)
    ]
  }

  autoscaling_group_launch_template_refs = {
    for asg_name, autoscaling_group in local.ec2_auto_scaling_groups :
    asg_name => try(autoscaling_group.launch_template, {})
  }

  autoscaling_group_launch_template_names = {
    for asg_name, launch_template in local.autoscaling_group_launch_template_refs :
    asg_name => lookup(
      var.launch_template_names_by_key,
      try(launch_template.name, ""),
      try(launch_template.name, null)
    )
  }

  autoscaling_group_launch_template_versions = {
    for asg_name, launch_template in local.autoscaling_group_launch_template_refs :
    asg_name => (
      try(launch_template.version, null) == null ? lookup(
        var.launch_template_latest_versions_by_key,
        try(launch_template.name, ""),
        "$Latest"
        ) : (
        contains(["$Latest", "$Default"], try(launch_template.version, "")) ? try(launch_template.version, null) : tostring(launch_template.version)
      )
    )
  }

  autoscaling_group_tags = {
    for asg_name, autoscaling_group in local.ec2_auto_scaling_groups :
    asg_name => concat(
      [
        {
          key                 = "Name"
          value               = autoscaling_group.name
          propagate_at_launch = true
        }
      ],
      [
        for tag_key, tag_value in try(autoscaling_group.tags, {}) : {
          key                 = tag_key
          value               = tostring(tag_value)
          propagate_at_launch = true
        }
      ],
      [
        for tag in try(autoscaling_group.additional_tags, try(autoscaling_group.tag_overrides, [])) : {
          key                 = tag.key
          value               = tostring(tag.value)
          propagate_at_launch = try(tag.propagate_at_launch, true)
        }
      ]
    )
  }
}

resource "aws_autoscaling_group" "managed" {
  for_each = local.ec2_auto_scaling_groups

  name                      = each.value.name
  min_size                  = try(each.value.min_size, 0)
  max_size                  = each.value.max_size
  desired_capacity          = try(each.value.desired_capacity, null)
  default_cooldown          = try(each.value.default_cooldown, null)
  force_delete              = try(each.value.force_delete, false)
  health_check_type         = try(each.value.health_check_type, "EC2")
  health_check_grace_period = try(each.value.health_check_grace_period, null)
  protect_from_scale_in     = try(each.value.protect_from_scale_in, false)
  termination_policies      = try(each.value.termination_policies, null)
  wait_for_capacity_timeout = try(each.value.wait_for_capacity_timeout, null)
  enabled_metrics           = try(each.value.enabled_metrics, null)
  metrics_granularity       = try(each.value.metrics_granularity, null)
  target_group_arns         = local.autoscaling_group_target_group_arns[each.key]
  vpc_zone_identifier       = local.autoscaling_group_subnet_ids[each.key]

  dynamic "launch_template" {
    for_each = local.autoscaling_group_launch_template_names[each.key] == null ? [] : [1]

    content {
      name    = local.autoscaling_group_launch_template_names[each.key]
      version = local.autoscaling_group_launch_template_versions[each.key]
    }
  }

  dynamic "instance_refresh" {
    for_each = try(each.value.instance_refresh, null) == null ? [] : [each.value.instance_refresh]

    content {
      strategy = try(instance_refresh.value.strategy, "Rolling")
      triggers = try(instance_refresh.value.triggers, null)

      dynamic "preferences" {
        for_each = try(instance_refresh.value.preferences, null) == null ? [] : [instance_refresh.value.preferences]

        content {
          checkpoint_delay             = try(preferences.value.checkpoint_delay, null)
          checkpoint_percentages       = try(preferences.value.checkpoint_percentages, null)
          instance_warmup              = try(preferences.value.instance_warmup, null)
          max_healthy_percentage       = try(preferences.value.max_healthy_percentage, null)
          min_healthy_percentage       = try(preferences.value.min_healthy_percentage, null)
          scale_in_protected_instances = try(preferences.value.scale_in_protected_instances, null)
          skip_matching                = try(preferences.value.skip_matching, null)
          standby_instances            = try(preferences.value.standby_instances, null)
        }
      }
    }
  }

  dynamic "tag" {
    for_each = local.autoscaling_group_tags[each.key]

    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = try(tag.value.propagate_at_launch, true)
    }
  }
}
