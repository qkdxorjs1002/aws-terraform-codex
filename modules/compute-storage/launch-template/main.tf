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

  launch_template_security_group_inputs = {
    for template_name, launch_template in local.ec2_launch_templates :
    template_name => [
      for security_group in try(launch_template.vpc_security_groups, try(launch_template.security_groups, [])) :
      tostring(security_group)
    ]
  }

  launch_template_cluster_reference_names = {
    for template_name, security_groups in local.launch_template_security_group_inputs :
    template_name => distinct(flatten([
      for security_group in security_groups : [
        for match in regexall("\\$\\{\\s*(cluster|eks_cluster)\\[\\\"([^\\\"]+)\\\"\\]", security_group) :
        match[1]
      ]
    ]))
  }

  launch_template_user_data_file_paths = {
    for template_name, launch_template in local.ec2_launch_templates :
    template_name => (
      try(launch_template.user_data_base64, null) != null || try(trimspace(launch_template.user_data_file), "") == "" ? null :
      startswith(trimspace(launch_template.user_data_file), "/") ?
      trimspace(launch_template.user_data_file) :
      "${path.root}/${trimspace(launch_template.user_data_file)}"
    )
  }

  launch_template_user_data_plain = {
    for template_name, launch_template in local.ec2_launch_templates :
    template_name => (
      try(launch_template.user_data_base64, null) != null ? null :
      local.launch_template_user_data_file_paths[template_name] != null ? file(local.launch_template_user_data_file_paths[template_name]) :
      try(launch_template.user_data, null) != null ? tostring(launch_template.user_data) :
      null
    )
  }

  launch_template_user_data_cluster_names = {
    for template_name, launch_template in local.ec2_launch_templates :
    template_name => (
      try(trimspace(tostring(launch_template.user_data_cluster)), "") != "" ? trimspace(tostring(launch_template.user_data_cluster)) :
      length(local.launch_template_cluster_reference_names[template_name]) == 1 ? local.launch_template_cluster_reference_names[template_name][0] :
      null
    )
  }

  launch_template_user_data_cluster_contexts = {
    for template_name, cluster_name in local.launch_template_user_data_cluster_names :
    template_name => cluster_name != null ? try(var.eks_cluster_attributes_by_name[cluster_name], null) : null
  }

  launch_template_resolved_user_data = {
    for template_name, user_data in local.launch_template_user_data_plain :
    template_name => user_data == null ? null : replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                user_data,
                "@@cluster.name@@",
                tostring(try(local.launch_template_user_data_cluster_contexts[template_name].name, ""))
              ),
              "@@cluster.arn@@",
              tostring(try(local.launch_template_user_data_cluster_contexts[template_name].arn, ""))
            ),
            "@@cluster.endpoint@@",
            tostring(try(local.launch_template_user_data_cluster_contexts[template_name].endpoint, ""))
          ),
          "@@cluster.certificate_authority@@",
          tostring(try(local.launch_template_user_data_cluster_contexts[template_name].certificate_authority, ""))
        ),
        "@@cluster.version@@",
        tostring(try(local.launch_template_user_data_cluster_contexts[template_name].version, ""))
      ),
      "@@cluster.security_group_id@@",
      tostring(try(local.launch_template_user_data_cluster_contexts[template_name].security_group_id, ""))
    )
  }

  launch_template_uses_cluster_context = {
    for template_name, security_groups in local.launch_template_security_group_inputs :
    template_name => anytrue(
      concat(
        [
          for security_group in security_groups :
          length(regexall("\\$\\{\\s*(cluster|eks_cluster)\\[", security_group)) > 0
        ],
        [
          local.launch_template_user_data_cluster_names[template_name] != null,
          length(regexall("@@(eks_)?cluster\\.", coalesce(local.launch_template_user_data_plain[template_name], ""))) > 0
        ]
      )
    )
  }

  launch_template_template_contexts = {
    for template_name in keys(local.ec2_launch_templates) :
    template_name => {
      security_group = var.security_group_ids_by_name
      cluster = local.launch_template_uses_cluster_context[template_name] ? var.eks_cluster_attributes_by_name : {}
      eks_cluster = local.launch_template_uses_cluster_context[template_name] ? var.eks_cluster_attributes_by_name : {}
    }
  }

  launch_template_resolved_security_group_ids = {
    for template_name, security_groups in local.launch_template_security_group_inputs :
    template_name => [
      for security_group in security_groups :
      lookup(
        var.security_group_ids_by_name,
        templatestring(security_group, local.launch_template_template_contexts[template_name]),
        templatestring(security_group, local.launch_template_template_contexts[template_name])
      )
    ]
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

  vpc_security_group_ids = local.launch_template_resolved_security_group_ids[each.key]

  user_data = (
    try(each.value.user_data_base64, null) != null ? each.value.user_data_base64 :
    local.launch_template_resolved_user_data[each.key] != null ? base64encode(local.launch_template_resolved_user_data[each.key]) :
    null
  )

  lifecycle {
    precondition {
      condition = (
        try(each.value.user_data_base64, null) != null ||
        local.launch_template_user_data_plain[each.key] == null ||
        length(regexall("@@(eks_)?cluster\\.", coalesce(local.launch_template_user_data_plain[each.key], ""))) == 0 ||
        local.launch_template_user_data_cluster_names[each.key] != null
      )
      error_message = "Launch template user_data_file cluster tokens require user_data_cluster, or exactly one cluster reference in vpc_security_groups/security_groups."
    }

    precondition {
      condition = (
        local.launch_template_user_data_cluster_names[each.key] == null ||
        contains(keys(var.eks_cluster_attributes_by_name), coalesce(local.launch_template_user_data_cluster_names[each.key], ""))
      )
      error_message = "Launch template user_data_cluster must reference an EKS cluster defined in eks_clusters."
    }
  }

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
