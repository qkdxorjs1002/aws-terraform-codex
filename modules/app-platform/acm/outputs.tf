output "certificate_arns_by_domain_name" {
  value = {
    for domain_name, certificate in aws_acm_certificate.managed :
    domain_name => certificate.arn
  }
}
