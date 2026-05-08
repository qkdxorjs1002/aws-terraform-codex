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

output "codedeploy_application_arns_by_name" {
  value = module.codedeploy.application_arns_by_name
}

output "codedeploy_deployment_group_names_by_key" {
  value = module.codedeploy.deployment_group_names_by_key
}

output "eip_allocation_ids_by_name" {
  value = module.eip.allocation_ids_by_name
}

output "eip_public_ips_by_name" {
  value = module.eip.public_ips_by_name
}

output "eip_arns_by_name" {
  value = module.eip.arns_by_name
}

output "alb_dns_names_by_name" {
  value = module.alb.load_balancer_dns_names_by_name
}

output "s3_bucket_regional_domain_names_by_name" {
  value = module.s3.bucket_regional_domain_names_by_name
}

output "ebs_volume_ids_by_name" {
  value = module.ebs.volume_ids_by_name
}

output "ebs_volume_arns_by_name" {
  value = module.ebs.volume_arns_by_name
}

output "efs_file_system_ids_by_name" {
  value = module.efs.file_system_ids_by_name
}

output "efs_file_system_arns_by_name" {
  value = module.efs.file_system_arns_by_name
}

output "efs_access_point_ids_by_key" {
  value = module.efs.access_point_ids_by_key
}

output "efs_access_point_arns_by_key" {
  value = module.efs.access_point_arns_by_key
}
