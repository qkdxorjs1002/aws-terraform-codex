output "certificate_arns_by_domain_name" {
  value = merge(
    {
      for domain_name, certificate in aws_acm_certificate.managed :
      domain_name => certificate.arn
    },
    {
      for domain_name, certificate in aws_acm_certificate_validation.wait_for_issued :
      domain_name => certificate.certificate_arn
    },
    {
      for domain_name, certificate in data.aws_acm_certificate.existing :
      domain_name => certificate.arn
    },
    local.existing_acm_certificates_with_arn
  )
}
