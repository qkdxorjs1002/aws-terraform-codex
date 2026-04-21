output "target_group_arns_by_key" {
  value = {
    for key, target_group in aws_lb_target_group.managed :
    key => target_group.arn
  }
}
