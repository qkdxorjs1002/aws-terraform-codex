resource "aws_security_group" "this" {
  name                   = var.name
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = var.revoke_rules_on_delete

  dynamic "ingress" {
    for_each = var.inbound_rules

    content {
      description = try(ingress.value.description, null)
      protocol    = ingress.value.protocol
      from_port   = ingress.value.protocol == "-1" ? 0 : ingress.value.from_port
      to_port     = ingress.value.protocol == "-1" ? 0 : ingress.value.to_port

      cidr_blocks      = ingress.value.peer_type == "ip" ? [ingress.value.peer_value] : null
      ipv6_cidr_blocks = ingress.value.peer_type == "ipv6" ? [ingress.value.peer_value] : null
      prefix_list_ids  = ingress.value.peer_type == "prefix-list" ? [ingress.value.peer_value] : null
      security_groups  = ingress.value.peer_type == "security-group" ? [ingress.value.peer_value] : null
      self             = ingress.value.peer_type == "self" ? true : null
    }
  }

  dynamic "egress" {
    for_each = var.outbound_rules

    content {
      description = try(egress.value.description, null)
      protocol    = egress.value.protocol
      from_port   = egress.value.protocol == "-1" ? 0 : egress.value.from_port
      to_port     = egress.value.protocol == "-1" ? 0 : egress.value.to_port

      cidr_blocks      = egress.value.peer_type == "ip" ? [egress.value.peer_value] : null
      ipv6_cidr_blocks = egress.value.peer_type == "ipv6" ? [egress.value.peer_value] : null
      prefix_list_ids  = egress.value.peer_type == "prefix-list" ? [egress.value.peer_value] : null
      security_groups  = egress.value.peer_type == "security-group" ? [egress.value.peer_value] : null
      self             = egress.value.peer_type == "self" ? true : null
    }
  }

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
