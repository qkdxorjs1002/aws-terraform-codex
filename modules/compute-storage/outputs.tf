output "ec2_launch_template_names_by_key" {
  value = module.launch_template.names_by_key
}

output "ec2_launch_template_latest_versions_by_key" {
  value = module.launch_template.latest_versions_by_key
}
