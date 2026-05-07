output "instance_ids_by_name" {
  value = {
    for name, instance in aws_instance.managed :
    name => instance.id
  }
}

output "instance_availability_zones_by_name" {
  value = {
    for name, instance in aws_instance.managed :
    name => instance.availability_zone
  }
}
