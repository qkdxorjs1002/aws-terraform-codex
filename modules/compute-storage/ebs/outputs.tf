output "volume_ids_by_name" {
  value = {
    for name, volume in aws_ebs_volume.managed :
    name => volume.id
  }
}

output "volume_arns_by_name" {
  value = {
    for name, volume in aws_ebs_volume.managed :
    name => volume.arn
  }
}
