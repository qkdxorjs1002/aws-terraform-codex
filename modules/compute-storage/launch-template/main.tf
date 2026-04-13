locals {
  ec2_launch_templates = {
    for launch_template in try(var.resources_by_type.ec2_launch_templates, []) :
    launch_template.name => launch_template
  }

  launch_template_image_inputs = {
    for template_name, launch_template in local.ec2_launch_templates :
    template_name => try(trimspace(launch_template.image_id), try(trimspace(launch_template.ami), ""))
  }

  launch_template_image_is_id = {
    for template_name, image_input in local.launch_template_image_inputs :
    template_name => length(regexall("^ami-[0-9a-fA-F]{8}([0-9a-fA-F]{9})?$", image_input)) > 0
  }
}

data "aws_ami" "launch_template_image_by_name" {
  for_each = {
    for template_name, launch_template in local.ec2_launch_templates :
    template_name => launch_template
    if local.launch_template_image_inputs[template_name] != "" && !local.launch_template_image_is_id[template_name]
  }

  most_recent = try(each.value.image_most_recent, true)
  owners      = try(each.value.image_owners, ["self"])

  filter {
    name   = "name"
    values = [local.launch_template_image_inputs[each.key]]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_launch_template" "managed" {
  for_each = local.ec2_launch_templates

  name        = try(each.value.template_name, each.value.name)
  description = try(each.value.description, null)

  image_id = (
    local.launch_template_image_inputs[each.key] == "" ? null :
    local.launch_template_image_is_id[each.key] ? local.launch_template_image_inputs[each.key] :
    data.aws_ami.launch_template_image_by_name[each.key].id
  )
  instance_type = try(each.value.instance_type, null)
  key_name      = try(each.value.key_name, null)

  update_default_version                = try(each.value.update_default_version, true)
  ebs_optimized                         = try(each.value.ebs_optimized, null)
  disable_api_termination               = try(each.value.termination_protection, null)
  instance_initiated_shutdown_behavior  = try(each.value.shutdown_behavior, null)

  vpc_security_group_ids = [
    for security_group in try(each.value.vpc_security_groups, try(each.value.security_groups, [])) :
    lookup(var.security_group_ids_by_name, security_group, security_group)
  ]

  user_data = try(each.value.user_data_base64, null) != null ? each.value.user_data_base64 : (
    try(each.value.user_data, null) != null ? base64encode(each.value.user_data) : null
  )

  dynamic "iam_instance_profile" {
    for_each = try(each.value.iam_instance_profile, try(each.value.iam_instance_profile_name, null)) == null ? [] : [try(each.value.iam_instance_profile, each.value.iam_instance_profile_name)]

    content {
      arn = can(iam_instance_profile.value.arn) ? try(iam_instance_profile.value.arn, null) : (
        startswith(tostring(iam_instance_profile.value), "arn:") ? tostring(iam_instance_profile.value) : null
      )
      name = can(iam_instance_profile.value.name) ? try(iam_instance_profile.value.name, null) : (
        startswith(tostring(iam_instance_profile.value), "arn:") ? null : tostring(iam_instance_profile.value)
      )
    }
  }

  dynamic "monitoring" {
    for_each = try(each.value.monitoring, null) == null ? [] : [each.value.monitoring]

    content {
      enabled = can(monitoring.value.enabled) ? try(monitoring.value.enabled, true) : tobool(monitoring.value)
    }
  }

  dynamic "metadata_options" {
    for_each = try(each.value.metadata_options, null) == null ? [] : [each.value.metadata_options]

    content {
      http_endpoint               = try(metadata_options.value.http_endpoint, "enabled")
      http_tokens                 = try(metadata_options.value.http_tokens, "required")
      http_protocol_ipv6          = try(metadata_options.value.http_protocol_ipv6, null)
      http_put_response_hop_limit = try(metadata_options.value.http_put_response_hop_limit, null)
      instance_metadata_tags      = try(metadata_options.value.instance_metadata_tags, "enabled")
    }
  }

  dynamic "block_device_mappings" {
    for_each = try(each.value.block_device_mappings, [])

    content {
      device_name  = try(block_device_mappings.value.device_name, null)
      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = try(block_device_mappings.value.virtual_name, null)

      dynamic "ebs" {
        for_each = try(block_device_mappings.value.ebs, null) == null ? [] : [block_device_mappings.value.ebs]

        content {
          delete_on_termination = try(ebs.value.delete_on_termination, true)
          encrypted             = try(ebs.value.encrypted, true)
          iops                  = try(ebs.value.iops, null)
          kms_key_id            = try(ebs.value.kms_key_id, null)
          snapshot_id           = try(ebs.value.snapshot_id, null)
          throughput            = try(ebs.value.throughput, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, "gp3")
        }
      }
    }
  }

  dynamic "tag_specifications" {
    for_each = try(each.value.tag_specifications, {})

    content {
      resource_type = tag_specifications.key
      tags          = try(tag_specifications.value, {})
    }
  }

  tags = merge(
    {
      Name = try(each.value.template_name, each.value.name)
    },
    try(each.value.tags, {})
  )
}
