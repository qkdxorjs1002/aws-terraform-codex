output "ec2_launch_template_names_by_key" {
  value = module.launch_template.names_by_key
}

output "ec2_launch_template_latest_versions_by_key" {
  value = module.launch_template.latest_versions_by_key
}

output "ec2_auto_scaling_group_arns_by_key" {
  value = module.asg.arns_by_key
}

output "ec2_auto_scaling_group_names_by_key" {
  value = module.asg.names_by_key
}
