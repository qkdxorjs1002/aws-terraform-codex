module "waf" {
  source = "./waf"

  resources_by_type = var.resources_by_type
}

module "cloudfront" {
  source = "./cloudfront"

  resources_by_type                       = var.resources_by_type
  waf_web_acl_arns_by_name                = module.waf.waf_web_acl_arns_by_name
  alb_dns_names_by_name                   = var.alb_dns_names_by_name
  s3_bucket_regional_domain_names_by_name = var.s3_bucket_regional_domain_names_by_name
  acm_certificate_arns_by_domain_name     = var.acm_certificate_arns_by_domain_name
}

module "ecs" {
  source = "./ecs"

  resources_by_type          = var.resources_by_type
  subnet_ids_by_name         = var.subnet_ids_by_name
  security_group_ids_by_name = var.security_group_ids_by_name
}

module "cloudwatch" {
  source = "./cloudwatch"

  resources_by_type = var.resources_by_type
}

moved {
  from = aws_wafv2_web_acl.managed
  to   = module.waf.aws_wafv2_web_acl.managed
}

moved {
  from = aws_cloudfront_origin_access_control.managed
  to   = module.cloudfront.aws_cloudfront_origin_access_control.managed
}

moved {
  from = aws_cloudfront_distribution.managed
  to   = module.cloudfront.aws_cloudfront_distribution.managed
}

moved {
  from = aws_ecs_cluster.managed
  to   = module.ecs.aws_ecs_cluster.managed
}

moved {
  from = aws_ecs_task_definition.managed
  to   = module.ecs.aws_ecs_task_definition.managed
}

moved {
  from = aws_ecs_service.managed
  to   = module.ecs.aws_ecs_service.managed
}

moved {
  from = aws_appautoscaling_target.ecs_service
  to   = module.ecs.aws_appautoscaling_target.ecs_service
}

moved {
  from = aws_appautoscaling_policy.ecs_service_cpu
  to   = module.ecs.aws_appautoscaling_policy.ecs_service_cpu
}

moved {
  from = aws_appautoscaling_policy.ecs_service_memory
  to   = module.ecs.aws_appautoscaling_policy.ecs_service_memory
}

moved {
  from = aws_cloudwatch_log_group.managed
  to   = module.cloudwatch.aws_cloudwatch_log_group.managed
}

moved {
  from = aws_cloudwatch_metric_alarm.managed
  to   = module.cloudwatch.aws_cloudwatch_metric_alarm.managed
}

moved {
  from = aws_cloudwatch_dashboard.managed
  to   = module.cloudwatch.aws_cloudwatch_dashboard.managed
}
