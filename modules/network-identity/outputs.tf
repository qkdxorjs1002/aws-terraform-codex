output "iam_role_arns_by_name" {
  value = {
    for name, role in aws_iam_role.managed :
    name => role.arn
  }
}
