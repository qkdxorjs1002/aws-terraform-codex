locals {
  sns_topics = {
    for topic in try(var.resources_by_type.sns_topics, []) :
    topic.name => topic
  }

  sns_subscriptions = {
    for idx, subscription in try(var.resources_by_type.sns_subscriptions, []) :
    "${subscription.topic}:${subscription.protocol}:${idx}" => subscription
  }
}

resource "aws_sns_topic" "managed" {
  for_each = local.sns_topics

  name                        = each.value.name
  fifo_topic                  = try(each.value.fifo_topic, false)
  content_based_deduplication = try(each.value.content_based_deduplication, false)
  kms_master_key_id           = try(each.value.kms_master_key_id, null)
  policy                      = try(each.value.policy, null)
  delivery_policy             = try(each.value.delivery_policy, null)

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_sns_topic_subscription" "managed" {
  for_each = local.sns_subscriptions

  topic_arn = lookup(
    { for name, topic in aws_sns_topic.managed : name => topic.arn },
    each.value.topic,
    each.value.topic
  )
  protocol                        = each.value.protocol
  endpoint                        = each.value.endpoint
  raw_message_delivery            = try(each.value.raw_message_delivery, false)
  filter_policy                   = try(each.value.filter_policy, null)
  redrive_policy                  = try(each.value.redrive_policy, null)
  endpoint_auto_confirms          = try(each.value.endpoint_auto_confirms, false)
  confirmation_timeout_in_minutes = try(each.value.confirmation_timeout_in_minutes, null)
}
