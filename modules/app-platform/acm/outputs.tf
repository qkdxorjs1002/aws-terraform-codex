output "regional_certificate_arns_by_domain_name" {
  value = merge(
    {
      for reference_name, certificate in aws_acm_certificate.managed :
      reference_name => certificate.arn
    },
    {
      for reference_name, certificate in aws_acm_certificate_validation.wait_for_issued :
      reference_name => certificate.certificate_arn
    },
    {
      for reference_name, certificate in data.aws_acm_certificate.existing :
      reference_name => certificate.arn
    },
    local.existing_acm_certificates_with_arn
  )
}

output "us_east_1_certificate_arns_by_domain_name" {
  value = merge(
    {
      for reference_name, certificate in aws_acm_certificate.managed_us_east_1 :
      reference_name => certificate.arn
    },
    {
      for reference_name, certificate in aws_acm_certificate_validation.wait_for_issued_us_east_1 :
      reference_name => certificate.certificate_arn
    },
    {
      for reference_name, certificate in data.aws_acm_certificate.existing_us_east_1 :
      reference_name => certificate.arn
    },
    local.existing_acm_certificates_with_arn_us_east_1
  )
}

output "certificate_arns_by_domain_name" {
  value = merge(
    {
      for reference_name, certificate in aws_acm_certificate.managed :
      reference_name => certificate.arn
    },
    {
      for reference_name, certificate in aws_acm_certificate_validation.wait_for_issued :
      reference_name => certificate.certificate_arn
    },
    {
      for reference_name, certificate in data.aws_acm_certificate.existing :
      reference_name => certificate.arn
    },
    local.existing_acm_certificates_with_arn,
    {
      for reference_name, certificate in aws_acm_certificate.managed_us_east_1 :
      reference_name => certificate.arn
    },
    {
      for reference_name, certificate in aws_acm_certificate_validation.wait_for_issued_us_east_1 :
      reference_name => certificate.certificate_arn
    },
    {
      for reference_name, certificate in data.aws_acm_certificate.existing_us_east_1 :
      reference_name => certificate.arn
    },
    local.existing_acm_certificates_with_arn_us_east_1
  )
}
