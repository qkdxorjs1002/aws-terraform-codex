output "file_system_ids_by_name" {
  value = {
    for name, file_system in aws_efs_file_system.managed :
    name => file_system.id
  }
}

output "file_system_arns_by_name" {
  value = {
    for name, file_system in aws_efs_file_system.managed :
    name => file_system.arn
  }
}

output "access_point_ids_by_key" {
  value = {
    for key, access_point in aws_efs_access_point.managed :
    key => access_point.id
  }
}

output "access_point_arns_by_key" {
  value = {
    for key, access_point in aws_efs_access_point.managed :
    key => access_point.arn
  }
}
