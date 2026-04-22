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

output "alb_dns_names_by_name" {
  value = module.alb.load_balancer_dns_names_by_name
}

output "s3_bucket_regional_domain_names_by_name" {
  value = module.s3.bucket_regional_domain_names_by_name
}
