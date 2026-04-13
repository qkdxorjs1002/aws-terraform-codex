locals {
  route53_hosted_zones = {
    for hosted_zone in try(var.resources_by_type.route53_hosted_zones, []) :
    hosted_zone.name => hosted_zone
  }

  route53_records = {
    for idx, record in try(var.resources_by_type.route53_records, []) :
    "${record.zone}:${record.name}:${record.type}:${idx}" => record
  }
}

resource "aws_route53_zone" "managed" {
  for_each = local.route53_hosted_zones

  name          = each.value.name
  comment       = try(each.value.comment, null)
  force_destroy = try(each.value.force_destroy, false)

  dynamic "vpc" {
    for_each = try(each.value.private_zone, false) ? try(each.value.vpc_associations, []) : []

    content {
      vpc_id     = lookup(var.vpc_ids_by_name, vpc.value.vpc, vpc.value.vpc)
      vpc_region = try(vpc.value.region, null)
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_route53_record" "managed" {
  for_each = local.route53_records

  zone_id = lookup({ for name, zone in aws_route53_zone.managed : name => zone.zone_id }, each.value.zone, each.value.zone)
  name    = each.value.name
  type    = each.value.type
  ttl     = try(each.value.alias.enabled, false) ? null : try(each.value.ttl, 300)
  records = try(each.value.alias.enabled, false) ? null : try(each.value.records, null)

  set_identifier                   = try(each.value.routing_policy.set_identifier, null)
  health_check_id                  = try(each.value.health_check_id, null)
  multivalue_answer_routing_policy = try(each.value.multivalue_answer_routing_policy, null)
  allow_overwrite                  = true

  dynamic "weighted_routing_policy" {
    for_each = try(each.value.routing_policy.type, null) == "weighted" ? [each.value.routing_policy] : []

    content {
      weight = try(weighted_routing_policy.value.weight, 100)
    }
  }

  dynamic "latency_routing_policy" {
    for_each = try(each.value.routing_policy.type, null) == "latency" ? [each.value.routing_policy] : []

    content {
      region = latency_routing_policy.value.region
    }
  }

  dynamic "failover_routing_policy" {
    for_each = try(each.value.routing_policy.type, null) == "failover" ? [each.value.routing_policy] : []

    content {
      type = failover_routing_policy.value.failover
    }
  }

  dynamic "alias" {
    for_each = try(each.value.alias.enabled, false) ? [each.value.alias] : []

    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = try(alias.value.evaluate_target_health, false)
    }
  }
}
