output "distribution_arns_by_name" {
  value = {
    for name, distribution in aws_cloudfront_distribution.managed :
    name => distribution.arn
  }
}
