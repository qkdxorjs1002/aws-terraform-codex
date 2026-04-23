locals {
  acm_certificates = {
    for certificate in try(var.resources_by_type.acm_certificates, []) :
    trimspace(tostring(certificate.domain_name)) => certificate
    if try(trimspace(tostring(certificate.domain_name)) != "", false)
  }

  # source=existing: lookup/import existing certificate and expose ARN by domain_name.
  # source=managed(default): create certificate through Terraform.
  managed_acm_certificates = {
    for domain_name, certificate in local.acm_certificates :
    domain_name => certificate
    if lower(trimspace(tostring(try(certificate.source, "managed")))) != "existing"
  }

  existing_acm_certificates_with_arn = {
    for domain_name, certificate in local.acm_certificates :
    domain_name => trimspace(tostring(certificate.certificate_arn))
    if lower(trimspace(tostring(try(certificate.source, "managed")))) == "existing" &&
    try(trimspace(tostring(certificate.certificate_arn)) != "", false)
  }

  existing_acm_certificates_for_lookup = {
    for domain_name, certificate in local.acm_certificates :
    domain_name => certificate
    if lower(trimspace(tostring(try(certificate.source, "managed")))) == "existing" &&
    try(trimspace(tostring(try(certificate.certificate_arn, ""))) == "", true)
  }

  managed_acm_certificates_wait_for_issued = {
    for domain_name, certificate in local.managed_acm_certificates :
    domain_name => certificate
    if try(certificate.wait_for_issued, false)
  }
}

resource "aws_acm_certificate" "managed" {
  for_each = local.managed_acm_certificates

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

resource "aws_acm_certificate_validation" "wait_for_issued" {
  for_each = local.managed_acm_certificates_wait_for_issued

  certificate_arn = aws_acm_certificate.managed[each.key].arn
  validation_record_fqdns = length(try(each.value.validation_record_fqdns, [])) > 0 ? try(each.value.validation_record_fqdns, null) : null
}

data "aws_acm_certificate" "existing" {
  for_each = local.existing_acm_certificates_for_lookup

  domain      = each.key
  statuses    = try(each.value.lookup_statuses, ["ISSUED"])
  most_recent = try(each.value.most_recent, true)
}
