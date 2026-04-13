resource "aws_vpc" "this" {
  cidr_block                       = var.cidr
  enable_dns_support               = var.enable_dns_support
  enable_dns_hostnames             = var.enable_dns_hostnames
  instance_tenancy                 = var.instance_tenancy
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "additional" {
  for_each = toset(var.additional_cidr_blocks)

  vpc_id     = aws_vpc.this.id
  cidr_block = each.value
}
