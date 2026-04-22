output "bucket_regional_domain_names_by_name" {
  value = {
    for name, bucket in aws_s3_bucket.managed :
    name => bucket.bucket_regional_domain_name
  }
}
