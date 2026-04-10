output "names_by_key" {
  value = {
    for key, launch_template in aws_launch_template.managed :
    key => launch_template.name
  }
}

output "latest_versions_by_key" {
  value = {
    for key, launch_template in aws_launch_template.managed :
    key => tostring(launch_template.latest_version)
  }
}
