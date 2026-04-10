output "waf_web_acl_arns_by_name" {
  value = {
    for name, acl in aws_wafv2_web_acl.managed :
    name => acl.arn
  }
}
