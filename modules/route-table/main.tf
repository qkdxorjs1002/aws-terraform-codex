resource "aws_route_table" "this" {
  vpc_id = var.vpc_id

  dynamic "route" {
    for_each = var.routes

    content {
      cidr_block                = route.value.destination_type == "cidr" ? route.value.destination_value : null
      ipv6_cidr_block           = route.value.destination_type == "ipv6" ? route.value.destination_value : null
      gateway_id                = contains(["internet-gateway", "gateway"], route.value.target_type) ? route.value.target_id : null
      nat_gateway_id            = route.value.target_type == "nat-gateway" ? route.value.target_id : null
      transit_gateway_id        = route.value.target_type == "transit-gateway" ? route.value.target_id : null
      vpc_endpoint_id           = route.value.target_type == "vpc-endpoint" ? route.value.target_id : null
      vpc_peering_connection_id = route.value.target_type == "vpc-peering-connection" ? route.value.target_id : null
      egress_only_gateway_id    = route.value.target_type == "egress-only-internet-gateway" ? route.value.target_id : null
      network_interface_id      = route.value.target_type == "network-interface" ? route.value.target_id : null
    }
  }

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

resource "aws_route_table_association" "this" {
  for_each = { for idx, subnet_id in var.associated_subnet_ids : tostring(idx) => subnet_id }

  subnet_id      = each.value
  route_table_id = aws_route_table.this.id
}
