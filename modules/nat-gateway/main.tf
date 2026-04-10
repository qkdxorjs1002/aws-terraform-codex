locals {
  normalized_connection_type = lower(var.connection_type) == "private" ? "private" : "public"
}

resource "aws_eip" "this" {
  count = local.normalized_connection_type == "public" && (var.allocation_id == null || trimspace(var.allocation_id) == "") ? 1 : 0

  domain = "vpc"

  tags = merge(
    {
      Name = "${var.name}-eip"
    },
    var.tags
  )
}

resource "aws_nat_gateway" "this" {
  subnet_id         = var.subnet_id
  connectivity_type = local.normalized_connection_type
  allocation_id = local.normalized_connection_type == "public" ? coalesce(
    var.allocation_id,
    try(aws_eip.this[0].id, null)
  ) : null

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
