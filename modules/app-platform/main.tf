module "kms" {
  source = "./kms"

  resources_by_type = var.resources_by_type
}

module "secrets" {
  source = "./secrets"

  resources_by_type = var.resources_by_type
}

module "ecr" {
  source = "./ecr"

  resources_by_type = var.resources_by_type
}

module "lambda" {
  source = "./lambda"

  resources_by_type          = var.resources_by_type
  subnet_ids_by_name         = var.subnet_ids_by_name
  security_group_ids_by_name = var.security_group_ids_by_name
}

module "api_gateway" {
  source = "./api-gateway"

  resources_by_type = var.resources_by_type
}

module "route53" {
  source = "./route53"

  resources_by_type = var.resources_by_type
  vpc_ids_by_name   = var.vpc_ids_by_name
}

module "acm" {
  source = "./acm"

  resources_by_type = var.resources_by_type
}

module "dynamodb" {
  source = "./dynamodb"

  resources_by_type = var.resources_by_type
}

module "elasticache" {
  source = "./elasticache"

  resources_by_type          = var.resources_by_type
  security_group_ids_by_name = var.security_group_ids_by_name
}

module "sqs" {
  source = "./sqs"

  resources_by_type = var.resources_by_type
}

module "sns" {
  source = "./sns"

  resources_by_type = var.resources_by_type
}

module "eventbridge" {
  source = "./eventbridge"

  resources_by_type = var.resources_by_type
}

moved {
  from = aws_kms_key.managed
  to   = module.kms.aws_kms_key.managed
}

moved {
  from = aws_kms_alias.managed
  to   = module.kms.aws_kms_alias.managed
}

moved {
  from = aws_secretsmanager_secret.managed
  to   = module.secrets.aws_secretsmanager_secret.managed
}

moved {
  from = aws_secretsmanager_secret_version.managed
  to   = module.secrets.aws_secretsmanager_secret_version.managed
}

moved {
  from = aws_secretsmanager_secret_rotation.managed
  to   = module.secrets.aws_secretsmanager_secret_rotation.managed
}

moved {
  from = aws_ecr_repository.managed
  to   = module.ecr.aws_ecr_repository.managed
}

moved {
  from = aws_ecr_repository_policy.managed
  to   = module.ecr.aws_ecr_repository_policy.managed
}

moved {
  from = aws_ecr_lifecycle_policy.managed
  to   = module.ecr.aws_ecr_lifecycle_policy.managed
}

moved {
  from = aws_cloudwatch_log_group.lambda
  to   = module.lambda.aws_cloudwatch_log_group.lambda
}

moved {
  from = aws_lambda_function.managed
  to   = module.lambda.aws_lambda_function.managed
}

moved {
  from = aws_apigatewayv2_api.managed
  to   = module.api_gateway.aws_apigatewayv2_api.managed
}

moved {
  from = aws_apigatewayv2_stage.default
  to   = module.api_gateway.aws_apigatewayv2_stage.default
}

moved {
  from = aws_apigatewayv2_integration.managed
  to   = module.api_gateway.aws_apigatewayv2_integration.managed
}

moved {
  from = aws_apigatewayv2_route.managed
  to   = module.api_gateway.aws_apigatewayv2_route.managed
}

moved {
  from = aws_route53_zone.managed
  to   = module.route53.aws_route53_zone.managed
}

moved {
  from = aws_route53_record.managed
  to   = module.route53.aws_route53_record.managed
}

moved {
  from = aws_acm_certificate.managed
  to   = module.acm.aws_acm_certificate.managed
}

moved {
  from = aws_dynamodb_table.managed
  to   = module.dynamodb.aws_dynamodb_table.managed
}

moved {
  from = aws_elasticache_replication_group.managed
  to   = module.elasticache.aws_elasticache_replication_group.managed
}

moved {
  from = aws_sqs_queue.managed
  to   = module.sqs.aws_sqs_queue.managed
}

moved {
  from = aws_sns_topic.managed
  to   = module.sns.aws_sns_topic.managed
}

moved {
  from = aws_sns_topic_subscription.managed
  to   = module.sns.aws_sns_topic_subscription.managed
}

moved {
  from = aws_cloudwatch_event_bus.managed
  to   = module.eventbridge.aws_cloudwatch_event_bus.managed
}

moved {
  from = aws_cloudwatch_event_bus_policy.managed
  to   = module.eventbridge.aws_cloudwatch_event_bus_policy.managed
}

moved {
  from = aws_cloudwatch_event_rule.managed
  to   = module.eventbridge.aws_cloudwatch_event_rule.managed
}

moved {
  from = aws_cloudwatch_event_target.managed
  to   = module.eventbridge.aws_cloudwatch_event_target.managed
}
