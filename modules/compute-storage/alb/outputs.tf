output "target_group_arns_by_key" {
  value = {
    for key, target_group in aws_lb_target_group.managed :
    key => target_group.arn
  }
}

output "target_group_names_by_key" {
  value = {
    for key, target_group in aws_lb_target_group.managed :
    key => target_group.name
  }
}

output "load_balancer_dns_names_by_name" {
  value = {
    for name, load_balancer in aws_lb.managed :
    name => load_balancer.dns_name
  }
}
