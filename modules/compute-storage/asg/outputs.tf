output "arns_by_key" {
  value = {
    for key, autoscaling_group in aws_autoscaling_group.managed :
    key => autoscaling_group.arn
  }
}

output "names_by_key" {
  value = {
    for key, autoscaling_group in aws_autoscaling_group.managed :
    key => autoscaling_group.name
  }
}
