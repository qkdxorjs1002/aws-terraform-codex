locals {
  ec2_instances = {
    for instance in try(var.resources_by_type.ec2_instances, []) :
    instance.name => instance
  }

  ec2_app_volumes = {
    for instance_name, instance in local.ec2_instances :
    instance_name => instance
    if try(instance.storage.app, null) != null
  }
}

resource "aws_instance" "managed" {
  for_each = local.ec2_instances

  ami           = each.value.ami
  instance_type = each.value.instance_type
  subnet_id     = lookup(var.subnet_ids_by_name, each.value.subnet, each.value.subnet)

  vpc_security_group_ids = [
    for security_group in try(each.value.security_groups, []) :
    lookup(var.security_group_ids_by_name, security_group, security_group)
  ]

  iam_instance_profile = try(each.value.iam_instance_profile, try(each.value.iam_role, null))

  key_name                    = try(each.value.key_name, null)
  private_ip                  = try(each.value.private_ip, null)
  associate_public_ip_address = try(each.value.associate_public_ip_address, false)
  monitoring                  = try(each.value.monitoring, true)
  ebs_optimized               = try(each.value.ebs_optimized, null)
  user_data                   = try(each.value.user_data, null)

  disable_api_termination = try(each.value.termination_protection, true)
  source_dest_check       = try(each.value.source_dest_check, true)

  dynamic "metadata_options" {
    for_each = try(each.value.metadata_options, null) == null ? [] : [each.value.metadata_options]

    content {
      http_endpoint          = try(metadata_options.value.http_endpoint, "enabled")
      http_tokens            = try(metadata_options.value.http_tokens, "required")
      instance_metadata_tags = try(metadata_options.value.instance_metadata_tags, "enabled")
    }
  }

  dynamic "credit_specification" {
    for_each = try(each.value.credit_specification, null) == null ? [] : [each.value.credit_specification]

    content {
      cpu_credits = try(credit_specification.value.cpu_credits, "standard")
    }
  }

  dynamic "root_block_device" {
    for_each = try(each.value.storage.root, null) == null ? [] : [each.value.storage.root]

    content {
      volume_type           = try(root_block_device.value.volume_type, "gp3")
      volume_size           = try(root_block_device.value.volume_size, 20)
      encrypted             = try(root_block_device.value.encrypted, true)
      delete_on_termination = try(root_block_device.value.delete_on_termination, true)
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_ebs_volume" "app" {
  for_each = local.ec2_app_volumes

  availability_zone = aws_instance.managed[each.key].availability_zone
  type              = try(each.value.storage.app.volume_type, "gp3")
  size              = try(each.value.storage.app.volume_size, 20)
  encrypted         = try(each.value.storage.app.encrypted, true)

  tags = merge(
    {
      Name = "${each.value.name}-app"
    },
    try(each.value.tags, {})
  )
}

resource "aws_volume_attachment" "app" {
  for_each = local.ec2_app_volumes

  device_name                    = try(each.value.storage.app.device_name, "/dev/sdf")
  volume_id                      = aws_ebs_volume.app[each.key].id
  instance_id                    = aws_instance.managed[each.key].id
  force_detach                   = false
  stop_instance_before_detaching = false
}
