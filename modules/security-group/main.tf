resource "aws_security_group" "this" {
  name                   = var.name
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = var.revoke_rules_on_delete

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
