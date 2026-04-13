locals {
  sqs_queues = {
    for queue in try(var.resources_by_type.sqs_queues, []) :
    queue.name => queue
  }
}

resource "aws_sqs_queue" "managed" {
  for_each = local.sqs_queues

  name                        = each.value.name
  fifo_queue                  = try(each.value.fifo_queue, false)
  content_based_deduplication = try(each.value.fifo_queue, false) ? try(each.value.content_based_deduplication, false) : null
  deduplication_scope         = try(each.value.fifo_queue, false) ? try(each.value.deduplication_scope, "queue") : null
  fifo_throughput_limit       = try(each.value.fifo_queue, false) ? try(each.value.fifo_throughput_limit, "perQueue") : null

  delay_seconds              = try(each.value.delay_seconds, 0)
  max_message_size           = try(each.value.max_message_size, 262144)
  message_retention_seconds  = try(each.value.message_retention_seconds, 345600)
  receive_wait_time_seconds  = try(each.value.receive_wait_time_seconds, 0)
  visibility_timeout_seconds = try(each.value.visibility_timeout_seconds, 30)

  kms_master_key_id                 = try(each.value.kms_master_key_id, null)
  kms_data_key_reuse_period_seconds = try(each.value.kms_data_key_reuse_period_seconds, null)

  redrive_policy = try(each.value.dead_letter_queue.enabled, false) ? jsonencode({
    deadLetterTargetArn = lookup(
      { for name, queue in aws_sqs_queue.managed : name => queue.arn },
      each.value.dead_letter_queue.target_queue_name,
      each.value.dead_letter_queue.target_queue_name
    )
    maxReceiveCount = try(each.value.dead_letter_queue.max_receive_count, 5)
  }) : null

  redrive_allow_policy = try(each.value.redrive_allow_policy, null)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}
