locals {
  ebs_volumes = {
    for volume in try(var.resources_by_type.ebs_volumes, []) :
    volume.name => volume
  }

  ebs_volume_attachments = {
    for attachment in flatten([
      for volume_name, volume in local.ebs_volumes : [
        for idx, volume_attachment in try(volume.attachments, []) : {
          key         = "${volume_name}:${idx}"
          volume_name = volume_name
          attachment  = volume_attachment
        }
      ]
    ]) :
    attachment.key => attachment
  }
}

resource "aws_ebs_volume" "managed" {
  for_each = local.ebs_volumes

  availability_zone = coalesce(
    try(each.value.availability_zone, null),
    try(each.value.availability_zone_name, null)
  )
  size                 = try(each.value.size, try(each.value.volume_size, null))
  type                 = try(each.value.type, try(each.value.volume_type, "gp3"))
  iops                 = try(each.value.iops, null)
  throughput           = try(each.value.throughput, null)
  encrypted            = try(each.value.encrypted, true)
  kms_key_id           = try(each.value.kms_key_id, null)
  snapshot_id          = try(each.value.snapshot_id, null)
  multi_attach_enabled = try(each.value.multi_attach_enabled, false)
  final_snapshot       = try(each.value.final_snapshot, false)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_volume_attachment" "managed" {
  for_each = local.ebs_volume_attachments

  device_name = try(each.value.attachment.device_name, "/dev/sdf")
  volume_id   = aws_ebs_volume.managed[each.value.volume_name].id
  instance_id = lookup(
    var.ec2_instance_ids_by_name,
    coalesce(
      try(each.value.attachment.instance_id, null),
      try(each.value.attachment.instance_name, null),
      try(each.value.attachment.instance, null)
    ),
    coalesce(
      try(each.value.attachment.instance_id, null),
      try(each.value.attachment.instance_name, null),
      try(each.value.attachment.instance, null)
    )
  )

  force_detach                   = try(each.value.attachment.force_detach, false)
  skip_destroy                   = try(each.value.attachment.skip_destroy, false)
  stop_instance_before_detaching = try(each.value.attachment.stop_instance_before_detaching, false)
}
