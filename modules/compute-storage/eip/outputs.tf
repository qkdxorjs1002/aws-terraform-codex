output "allocation_ids_by_name" {
  value = {
    for name, address in aws_eip.managed :
    name => address.allocation_id
  }
}

output "public_ips_by_name" {
  value = {
    for name, address in aws_eip.managed :
    name => address.public_ip
  }
}

output "arns_by_name" {
  value = {
    for name, address in aws_eip.managed :
    name => address.arn
  }
}
