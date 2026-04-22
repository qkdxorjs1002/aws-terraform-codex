output "application_arns_by_name" {
  value = {
    for name, application in aws_codedeploy_app.managed :
    name => application.arn
  }
}

output "deployment_group_names_by_key" {
  value = {
    for key, deployment_group in aws_codedeploy_deployment_group.managed :
    key => deployment_group.deployment_group_name
  }
}

output "deployment_group_ids_by_key" {
  value = {
    for key, deployment_group in aws_codedeploy_deployment_group.managed :
    key => deployment_group.id
  }
}
