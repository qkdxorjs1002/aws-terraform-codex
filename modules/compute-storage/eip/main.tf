locals {
  eip_addresses = {
    for address in try(var.resources_by_type.eip_addresses, []) :
    address.name => address
  }
}

resource "aws_eip" "managed" {
  for_each = local.eip_addresses

  domain               = try(each.value.domain, "vpc")
  address              = try(each.value.address, null)
  public_ipv4_pool     = try(each.value.public_ipv4_pool, null)
  network_border_group = try(each.value.network_border_group, null)
  customer_owned_ipv4_pool = try(
    each.value.customer_owned_ipv4_pool,
    null
  )
  ipam_pool_id = try(each.value.ipam_pool_id, null)

  instance = try(
    lookup(
      var.ec2_instance_ids_by_name,
      coalesce(
        try(each.value.instance_id, null),
        try(each.value.instance_name, null),
        try(each.value.instance, null)
      ),
      coalesce(
        try(each.value.instance_id, null),
        try(each.value.instance_name, null),
        try(each.value.instance, null)
      )
    ),
    null
  )

  associate_with_private_ip = try(each.value.associate_with_private_ip, null)
  network_interface         = try(each.value.network_interface_id, try(each.value.network_interface, null))

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}
