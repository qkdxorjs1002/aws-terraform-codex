module "rds" {
  source = "./rds"

  resources_by_type          = var.resources_by_type
  subnet_ids_by_name         = var.subnet_ids_by_name
  security_group_ids_by_name = var.security_group_ids_by_name
  iam_role_arns_by_name      = var.iam_role_arns_by_name
}

module "ec2" {
  source = "./ec2"

  resources_by_type          = var.resources_by_type
  subnet_ids_by_name         = var.subnet_ids_by_name
  security_group_ids_by_name = var.security_group_ids_by_name
}

module "launch_template" {
  source = "./launch-template"

  resources_by_type              = var.resources_by_type
  security_group_ids_by_name     = var.security_group_ids_by_name
  eks_cluster_attributes_by_name = var.eks_cluster_attributes_by_name
}

module "alb" {
  source = "./alb"

  resources_by_type                  = var.resources_by_type
  vpc_ids_by_name                    = var.vpc_ids_by_name
  subnet_ids_by_name                 = var.subnet_ids_by_name
  security_group_ids_by_name         = var.security_group_ids_by_name
  acm_certificate_arns_by_domain_name = var.acm_certificate_arns_by_domain_name
}

module "asg" {
  source = "./asg"

  resources_by_type                      = var.resources_by_type
  subnet_ids_by_name                     = var.subnet_ids_by_name
  launch_template_names_by_key           = module.launch_template.names_by_key
  launch_template_latest_versions_by_key = module.launch_template.latest_versions_by_key
  alb_target_group_arns_by_key           = module.alb.target_group_arns_by_key
}

module "codedeploy" {
  source = "./codedeploy"

  resources_by_type               = var.resources_by_type
  iam_role_arns_by_name           = var.iam_role_arns_by_name
  auto_scaling_group_names_by_key = module.asg.names_by_key
  alb_target_group_names_by_key   = module.alb.target_group_names_by_key
}

module "s3" {
  source = "./s3"

  resources_by_type = var.resources_by_type
}

moved {
  from = aws_db_subnet_group.managed
  to   = module.rds.aws_db_subnet_group.managed
}

moved {
  from = aws_db_instance.managed
  to   = module.rds.aws_db_instance.managed
}

moved {
  from = aws_instance.managed
  to   = module.ec2.aws_instance.managed
}

moved {
  from = aws_ebs_volume.app
  to   = module.ec2.aws_ebs_volume.app
}

moved {
  from = aws_volume_attachment.app
  to   = module.ec2.aws_volume_attachment.app
}

moved {
  from = aws_lb_target_group.managed
  to   = module.alb.aws_lb_target_group.managed
}

moved {
  from = aws_lb.managed
  to   = module.alb.aws_lb.managed
}

moved {
  from = aws_lb_listener.managed
  to   = module.alb.aws_lb_listener.managed
}

moved {
  from = aws_s3_bucket.managed
  to   = module.s3.aws_s3_bucket.managed
}

moved {
  from = aws_s3_bucket_ownership_controls.managed
  to   = module.s3.aws_s3_bucket_ownership_controls.managed
}

moved {
  from = aws_s3_bucket_versioning.managed
  to   = module.s3.aws_s3_bucket_versioning.managed
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.managed
  to   = module.s3.aws_s3_bucket_server_side_encryption_configuration.managed
}

moved {
  from = aws_s3_bucket_public_access_block.managed
  to   = module.s3.aws_s3_bucket_public_access_block.managed
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.managed
  to   = module.s3.aws_s3_bucket_lifecycle_configuration.managed
}

moved {
  from = aws_s3_bucket_cors_configuration.managed
  to   = module.s3.aws_s3_bucket_cors_configuration.managed
}

moved {
  from = aws_s3_bucket_logging.managed
  to   = module.s3.aws_s3_bucket_logging.managed
}
