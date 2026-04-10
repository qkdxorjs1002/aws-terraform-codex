locals {
  ec2_alb_target_groups = {
    for target_group in try(var.resources_by_type.ec2_alb_target_groups, []) :
    target_group.name => target_group
  }

  ec2_load_balancers = {
    for load_balancer in try(var.resources_by_type.ec2_load_balancers, []) :
    load_balancer.name => load_balancer
  }

  ec2_lb_listeners = flatten([
    for load_balancer_name, load_balancer in local.ec2_load_balancers : [
      for idx, listener in try(load_balancer.listeners, []) : {
        key                = "${load_balancer_name}:${idx}"
        load_balancer_name = load_balancer_name
        listener           = listener
      }
    ]
  ])
}

resource "aws_lb_target_group" "managed" {
  for_each = local.ec2_alb_target_groups

  name        = each.value.name
  target_type = try(each.value.type, "instance")
  vpc_id      = lookup(var.vpc_ids_by_name, each.value.vpc, each.value.vpc)
  protocol    = try(each.value.protocol, "HTTP")
  port        = try(each.value.port, 80)

  deregistration_delay = try(each.value.deregistration_delay, 300)
  slow_start           = try(each.value.slow_start, 0)

  dynamic "stickiness" {
    for_each = try(each.value.stickiness, null) == null ? [] : [each.value.stickiness]

    content {
      enabled         = try(stickiness.value.enabled, false)
      type            = try(stickiness.value.type, "lb_cookie")
      cookie_duration = try(stickiness.value.cookie_duration, 86400)
    }
  }

  dynamic "health_check" {
    for_each = try(each.value.health_check, null) == null ? [] : [each.value.health_check]

    content {
      protocol            = try(health_check.value.protocol, "HTTP")
      path                = try(health_check.value.path, "/")
      healthy_threshold   = try(health_check.value.healthy_threshold, 5)
      unhealthy_threshold = try(health_check.value.unhealthy_threshold, 2)
      timeout             = try(health_check.value.timeout_seconds, 5)
      interval            = try(health_check.value.interval_seconds, 30)
      matcher             = tostring(try(health_check.value.success_codes, 200))
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_lb" "managed" {
  for_each = local.ec2_load_balancers

  name               = each.value.name
  load_balancer_type = try(each.value.type, "application")
  internal           = try(each.value.scheme, "internet-facing") == "internal"
  ip_address_type    = try(each.value.ip_address_type, "ipv4")

  subnets = [
    for subnet_info in try(each.value.subnets, []) :
    lookup(var.subnet_ids_by_name, try(subnet_info.subnet, subnet_info), try(subnet_info.subnet, subnet_info))
  ]

  security_groups = try(each.value.type, "application") == "application" ? [
    for security_group in try(each.value.security_groups, []) :
    lookup(var.security_group_ids_by_name, security_group, security_group)
  ] : null

  enable_deletion_protection = try(each.value.enable_deletion_protection, true)
  idle_timeout               = try(each.value.idle_timeout, 60)
  drop_invalid_header_fields = try(each.value.drop_invalid_header_fields, true)

  dynamic "access_logs" {
    for_each = try(each.value.access_logs.enabled, false) ? [each.value.access_logs] : []

    content {
      enabled = true
      bucket  = access_logs.value.bucket
      prefix  = try(access_logs.value.prefix, null)
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_lb_listener" "managed" {
  for_each = {
    for listener in local.ec2_lb_listeners :
    listener.key => listener
  }

  load_balancer_arn = aws_lb.managed[each.value.load_balancer_name].arn
  protocol          = try(each.value.listener.protocol, "HTTP")
  port              = try(each.value.listener.port, 80)
  ssl_policy        = try(each.value.listener.ssl_policy, null)
  certificate_arn   = try(each.value.listener.certificate_arn, null)

  default_action {
    type = "forward"
    target_group_arn = lookup(
      { for name, target_group in aws_lb_target_group.managed : name => target_group.arn },
      try(each.value.listener.target_groups[0], ""),
      try(each.value.listener.target_groups[0], "")
    )
  }
}
