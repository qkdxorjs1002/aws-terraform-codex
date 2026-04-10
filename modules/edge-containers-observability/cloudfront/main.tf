locals {
  cloudfront_origin_access_controls = {
    for oac in try(var.resources_by_type.cloudfront_origin_access_controls, []) :
    oac.name => oac
  }

  cloudfront_distributions = {
    for distribution in try(var.resources_by_type.cloudfront_distributions, []) :
    distribution.name => distribution
  }

  cloudfront_oac_ids_by_name = {
    for name, oac in aws_cloudfront_origin_access_control.managed :
    name => oac.id
  }
}

resource "aws_cloudfront_origin_access_control" "managed" {
  for_each = local.cloudfront_origin_access_controls

  name                              = each.value.name
  description                       = try(each.value.description, null)
  origin_access_control_origin_type = try(each.value.origin_type, "s3")
  signing_behavior                  = try(each.value.signing_behavior, "always")
  signing_protocol                  = try(each.value.signing_protocol, "sigv4")
}

resource "aws_cloudfront_distribution" "managed" {
  for_each = local.cloudfront_distributions

  enabled             = try(each.value.enabled, true)
  is_ipv6_enabled     = try(each.value.is_ipv6_enabled, true)
  comment             = try(each.value.comment, null)
  aliases             = try(each.value.aliases, [])
  default_root_object = try(each.value.default_root_object, null)
  price_class         = try(each.value.price_class, "PriceClass_All")
  http_version        = try(each.value.http_version, "http2")
  wait_for_deployment = try(each.value.wait_for_deployment, true)
  retain_on_delete    = try(each.value.retain_on_delete, false)
  web_acl_id = (
    try(each.value.web_acl, null) == null ? null : lookup(
      var.waf_web_acl_arns_by_name,
      each.value.web_acl,
      each.value.web_acl
    )
  )

  dynamic "origin" {
    for_each = try(each.value.origins, [])

    content {
      domain_name              = origin.value.domain_name
      origin_id                = origin.value.id
      origin_path              = try(origin.value.origin_path, null)
      origin_access_control_id = try(origin.value.origin_access_control, null) == null ? null : lookup(local.cloudfront_oac_ids_by_name, origin.value.origin_access_control, origin.value.origin_access_control)

      dynamic "custom_origin_config" {
        for_each = try(origin.value.type, "custom") == "custom" ? [try(origin.value.custom_origin_config, {})] : []

        content {
          http_port                = try(custom_origin_config.value.http_port, 80)
          https_port               = try(custom_origin_config.value.https_port, 443)
          origin_protocol_policy   = try(custom_origin_config.value.origin_protocol_policy, "https-only")
          origin_ssl_protocols     = try(custom_origin_config.value.origin_ssl_protocols, ["TLSv1.2"])
          origin_read_timeout      = 30
          origin_keepalive_timeout = 5
        }
      }

      dynamic "s3_origin_config" {
        for_each = try(origin.value.type, "custom") == "s3" ? [1] : []

        content {
          origin_access_identity = ""
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = each.value.default_cache_behavior.target_origin_id
    viewer_protocol_policy = try(each.value.default_cache_behavior.viewer_protocol_policy, "redirect-to-https")
    allowed_methods        = try(each.value.default_cache_behavior.allowed_methods, ["GET", "HEAD", "OPTIONS"])
    cached_methods         = try(each.value.default_cache_behavior.cached_methods, ["GET", "HEAD"])
    compress               = try(each.value.default_cache_behavior.compress, true)

    cache_policy_id            = try(each.value.default_cache_behavior.cache_policy_id, null)
    origin_request_policy_id   = try(each.value.default_cache_behavior.origin_request_policy_id, null)
    response_headers_policy_id = try(each.value.default_cache_behavior.response_headers_policy_id, null)

    dynamic "forwarded_values" {
      for_each = try(each.value.default_cache_behavior.cache_policy_id, null) == null ? [1] : []

      content {
        query_string = true
        cookies {
          forward = "all"
        }
      }
    }
  }

  dynamic "custom_error_response" {
    for_each = try(each.value.custom_error_responses, [])

    content {
      error_code            = custom_error_response.value.error_code
      response_code         = try(custom_error_response.value.response_code, null)
      response_page_path    = try(custom_error_response.value.response_page_path, null)
      error_caching_min_ttl = try(custom_error_response.value.error_caching_min_ttl, null)
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = try(each.value.restrictions.geo_restriction.restriction_type, "none")
      locations        = try(each.value.restrictions.geo_restriction.locations, [])
    }
  }

  viewer_certificate {
    acm_certificate_arn            = try(each.value.viewer_certificate.acm_certificate_arn, null)
    ssl_support_method             = try(each.value.viewer_certificate.ssl_support_method, null)
    minimum_protocol_version       = try(each.value.viewer_certificate.minimum_protocol_version, "TLSv1.2_2021")
    cloudfront_default_certificate = try(each.value.viewer_certificate.acm_certificate_arn, null) == null
  }

  dynamic "logging_config" {
    for_each = try(each.value.logging.enabled, false) ? [each.value.logging] : []

    content {
      bucket          = logging_config.value.bucket
      include_cookies = try(logging_config.value.include_cookies, false)
      prefix          = try(logging_config.value.prefix, null)
    }
  }

  tags = try(each.value.tags, {})
}
