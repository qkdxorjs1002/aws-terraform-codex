resource "aws_subnet" "this" {
  vpc_id                          = var.vpc_id
  cidr_block                      = var.cidr_block
  availability_zone               = var.availability_zone
  map_public_ip_on_launch         = var.map_public_ip_on_launch
  assign_ipv6_address_on_creation = var.assign_ipv6_address_on_creation

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
