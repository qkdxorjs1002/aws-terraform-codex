locals {
  acm_certificates = {
    for certificate in try(var.resources_by_type.acm_certificates, []) :
    certificate.domain_name => certificate
  }
}

resource "aws_acm_certificate" "managed" {
  for_each = local.acm_certificates

  domain_name               = each.value.domain_name
  subject_alternative_names = try(each.value.subject_alternative_names, [])
  validation_method         = try(each.value.validation_method, "DNS")
  key_algorithm             = try(each.value.key_algorithm, null)

  options {
    certificate_transparency_logging_preference = try(each.value.transparency_logging_enabled, true) ? "ENABLED" : "DISABLED"
  }

  tags = merge(
    {
      Name = startswith(each.value.domain_name, "*.") ? "wildcard-${trimprefix(each.value.domain_name, "*.")}" : each.value.domain_name
    },
    try(each.value.tags, {})
  )
}
