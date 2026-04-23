output "acm_certificate_arns_by_domain_name" {
  value = module.acm.certificate_arns_by_domain_name
}

output "acm_regional_certificate_arns_by_domain_name" {
  value = module.acm.regional_certificate_arns_by_domain_name
}

output "acm_us_east_1_certificate_arns_by_domain_name" {
  value = module.acm.us_east_1_certificate_arns_by_domain_name
}
