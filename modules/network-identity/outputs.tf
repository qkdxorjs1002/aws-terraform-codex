output "iam_role_arns_by_name" {
  value = local.iam_role_arns_by_name
}

output "iam_instance_profile_names_by_role_name" {
  value = {
    for role_name, instance_profile in aws_iam_instance_profile.managed :
    role_name => instance_profile.name
  }
}

output "iam_user_arns_by_name" {
  value = {
    for name, user in aws_iam_user.managed :
    name => user.arn
  }
}

output "iam_group_arns_by_name" {
  value = {
    for name, group in aws_iam_group.managed :
    name => group.arn
  }
}

output "iam_policy_arns_by_name" {
  value = local.iam_policy_arns_by_name
}

output "iam_oidc_provider_arns_by_key" {
  value = {
    for key, provider in aws_iam_openid_connect_provider.managed :
    key => provider.arn
  }
}

output "iam_oidc_provider_arns_by_url" {
  value = {
    for _, provider in aws_iam_openid_connect_provider.managed :
    provider.url => provider.arn
  }
}
