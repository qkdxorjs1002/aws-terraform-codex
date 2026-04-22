locals {
  cloudfront_origin_access_controls = {
    for oac in try(var.resources_by_type.cloudfront_origin_access_controls, []) :
    oac.name => oac
  }

  cloudfront_functions = {
    for cloudfront_function in try(var.resources_by_type.cloudfront_functions, []) :
    cloudfront_function.name => cloudfront_function
  }

  cloudfront_distributions = {
    for distribution in try(var.resources_by_type.cloudfront_distributions, []) :
    distribution.name => distribution
  }

  cloudfront_oac_ids_by_name = {
    for name, oac in aws_cloudfront_origin_access_control.managed :
    name => oac.id
  }

  cloudfront_function_arns_by_name = {
    for name, cloudfront_function in aws_cloudfront_function.managed :
    name => cloudfront_function.arn
  }

  # Managed policy IDs from AWS CloudFront docs.
  cloudfront_managed_cache_policy_ids_by_name = {
    "Amplify"                                           = "2e54312d-136d-493c-8eb9-b001f22f67d2"
    "Managed-Amplify"                                   = "2e54312d-136d-493c-8eb9-b001f22f67d2"
    "CachingDisabled"                                   = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    "Managed-CachingDisabled"                           = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    "CachingOptimized"                                  = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    "Managed-CachingOptimized"                          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    "CachingOptimizedForUncompressedObjects"            = "b2884449-e4de-46a7-ac36-70bc7f1ddd6d"
    "Managed-CachingOptimizedForUncompressedObjects"    = "b2884449-e4de-46a7-ac36-70bc7f1ddd6d"
    "Elemental-MediaPackage"                            = "08627262-05a9-4f76-9ded-b50ca2e3a84f"
    "Managed-Elemental-MediaPackage"                    = "08627262-05a9-4f76-9ded-b50ca2e3a84f"
    "UseOriginCacheControlHeaders"                      = "83da9c7e-98b4-4e11-a168-04f0df8e2c65"
    "Managed-UseOriginCacheControlHeaders"              = "83da9c7e-98b4-4e11-a168-04f0df8e2c65"
    "UseOriginCacheControlHeaders-QueryStrings"         = "4cc15a8a-d715-48a4-82b8-cc0b614638fe"
    "Managed-UseOriginCacheControlHeaders-QueryStrings" = "4cc15a8a-d715-48a4-82b8-cc0b614638fe"
  }

  cloudfront_managed_origin_request_policy_ids_by_name = {
    "AllViewer"                                             = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    "Managed-AllViewer"                                     = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    "AllViewerAndCloudFrontHeaders-2022-06"                 = "33f36d7e-f396-46d9-90e0-52428a34d9dc"
    "Managed-AllViewerAndCloudFrontHeaders-2022-06"         = "33f36d7e-f396-46d9-90e0-52428a34d9dc"
    "AllViewerExceptHostHeader"                             = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    "Managed-AllViewerExceptHostHeader"                     = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    "CORS-CustomOrigin"                                     = "59781a5b-3903-41f3-afcb-af62929ccde1"
    "Managed-CORS-CustomOrigin"                             = "59781a5b-3903-41f3-afcb-af62929ccde1"
    "CORS-S3Origin"                                         = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
    "Managed-CORS-S3Origin"                                 = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
    "Elemental-MediaTailor-PersonalizedManifests"           = "775133bc-15f2-49f9-abea-afb2e0bf67d2"
    "Managed-Elemental-MediaTailor-PersonalizedManifests"   = "775133bc-15f2-49f9-abea-afb2e0bf67d2"
    "HostHeaderOnly"                                        = "bf0718e1-ba1e-49d1-88b1-f726733018ae"
    "Managed-HostHeaderOnly"                                = "bf0718e1-ba1e-49d1-88b1-f726733018ae"
    "UserAgentRefererHeaders"                               = "acba4595-bd28-49b8-b9fe-13317c0390fa"
    "Managed-UserAgentRefererHeaders"                       = "acba4595-bd28-49b8-b9fe-13317c0390fa"
  }

  cloudfront_managed_response_headers_policy_ids_by_name = {
    "CORS-and-SecurityHeadersPolicy"                        = "e61eb60c-9c35-4d20-a928-2b84e02af89c"
    "Managed-CORS-and-SecurityHeadersPolicy"                = "e61eb60c-9c35-4d20-a928-2b84e02af89c"
    "CORS-With-Preflight"                                   = "5cc3b908-e619-4b99-88e5-2cf7f45965bd"
    "Managed-CORS-With-Preflight"                           = "5cc3b908-e619-4b99-88e5-2cf7f45965bd"
    "CORS-with-preflight-and-SecurityHeadersPolicy"         = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
    "Managed-CORS-with-preflight-and-SecurityHeadersPolicy" = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
    "SecurityHeadersPolicy"                                 = "67f7725c-6f97-4210-82d7-5512b31e9d03"
    "Managed-SecurityHeadersPolicy"                         = "67f7725c-6f97-4210-82d7-5512b31e9d03"
    "SimpleCORS"                                            = "60669652-455b-4ae9-85a4-c4c02393f86c"
    "Managed-SimpleCORS"                                    = "60669652-455b-4ae9-85a4-c4c02393f86c"
  }

  cloudfront_cache_policy_names = toset([
    for name in concat(
      [for distribution in values(local.cloudfront_distributions) : try(trimspace(distribution.default_cache_behavior.cache_policy_name), "")],
      flatten([
        for distribution in values(local.cloudfront_distributions) : [
          for cache_behavior in try(distribution.cache_behaviors, []) :
          try(trimspace(cache_behavior.cache_policy_name), "")
        ]
      ])
    ) :
    name
    if name != ""
  ])

  cloudfront_cache_policy_lookup_names = toset([
    for name in local.cloudfront_cache_policy_names :
    name
    if !contains(keys(local.cloudfront_managed_cache_policy_ids_by_name), name)
  ])

  cloudfront_origin_request_policy_names = toset([
    for name in concat(
      [for distribution in values(local.cloudfront_distributions) : try(trimspace(distribution.default_cache_behavior.origin_request_policy_name), "")],
      flatten([
        for distribution in values(local.cloudfront_distributions) : [
          for cache_behavior in try(distribution.cache_behaviors, []) :
          try(trimspace(cache_behavior.origin_request_policy_name), "")
        ]
      ])
    ) :
    name
    if name != ""
  ])

  cloudfront_origin_request_policy_lookup_names = toset([
    for name in local.cloudfront_origin_request_policy_names :
    name
    if !contains(keys(local.cloudfront_managed_origin_request_policy_ids_by_name), name)
  ])

  cloudfront_response_headers_policy_names = toset([
    for name in concat(
      [for distribution in values(local.cloudfront_distributions) : try(trimspace(distribution.default_cache_behavior.response_headers_policy_name), "")],
      flatten([
        for distribution in values(local.cloudfront_distributions) : [
          for cache_behavior in try(distribution.cache_behaviors, []) :
          try(trimspace(cache_behavior.response_headers_policy_name), "")
        ]
      ])
    ) :
    name
    if name != ""
  ])

  cloudfront_response_headers_policy_lookup_names = toset([
    for name in local.cloudfront_response_headers_policy_names :
    name
    if !contains(keys(local.cloudfront_managed_response_headers_policy_ids_by_name), name)
  ])

  # CloudFront origin.domain_name can reference managed resource names (for example ALB/S3)
  # and is resolved to real domain names for provisioning.
  cloudfront_origin_domain_names_by_reference = merge(
    var.alb_dns_names_by_name,
    var.s3_bucket_regional_domain_names_by_name
  )

  # target_origin_id/target_origin_name can be written as origin id, origin name, or origin domain reference.
  cloudfront_origin_ids_by_distribution = {
    for distribution_name, distribution in local.cloudfront_distributions :
    distribution_name => merge(
      {
        for origin in try(distribution.origins, []) :
        tostring(origin.id) => tostring(origin.id)
        if try(origin.id, null) != null
      },
      {
        for origin in try(distribution.origins, []) :
        tostring(origin.name) => tostring(origin.id)
        if try(origin.name, null) != null && try(origin.id, null) != null
      },
      {
        for origin in try(distribution.origins, []) :
        tostring(origin.domain_name) => tostring(origin.id)
        if try(origin.domain_name, null) != null && try(origin.id, null) != null
      },
      {
        for origin in try(distribution.origins, []) :
        lookup(
          local.cloudfront_origin_domain_names_by_reference,
          tostring(origin.domain_name),
          tostring(origin.domain_name)
        ) => tostring(origin.id)
        if try(origin.domain_name, null) != null && try(origin.id, null) != null
      }
    )
  }

  # viewer_certificate.acm_certificate_name maps to acm_certificates[].domain_name.
  cloudfront_viewer_certificate_arns_by_distribution = {
    for distribution_name, distribution in local.cloudfront_distributions :
    distribution_name => try(coalesce(
      try(distribution.viewer_certificate.acm_certificate_arn, null),
      lookup(
        var.acm_certificate_arns_by_domain_name,
        trimspace(tostring(coalesce(
          try(distribution.viewer_certificate.acm_certificate_name, null),
          try(distribution.viewer_certificate.acm_certificate_domain_name, null),
          ""
        ))),
        null
      )
    ), null)
  }
}

data "aws_cloudfront_cache_policy" "by_name" {
  for_each = local.cloudfront_cache_policy_lookup_names
  name     = each.value
}

data "aws_cloudfront_origin_request_policy" "by_name" {
  for_each = local.cloudfront_origin_request_policy_lookup_names
  name     = each.value
}

data "aws_cloudfront_response_headers_policy" "by_name" {
  for_each = local.cloudfront_response_headers_policy_lookup_names
  name     = each.value
}

locals {
  cloudfront_cache_policy_ids_by_name = merge(
    {
      for name in local.cloudfront_cache_policy_names :
      name => local.cloudfront_managed_cache_policy_ids_by_name[name]
      if contains(keys(local.cloudfront_managed_cache_policy_ids_by_name), name)
    },
    {
      for name, policy in data.aws_cloudfront_cache_policy.by_name :
      name => policy.id
    }
  )

  cloudfront_origin_request_policy_ids_by_name = merge(
    {
      for name in local.cloudfront_origin_request_policy_names :
      name => local.cloudfront_managed_origin_request_policy_ids_by_name[name]
      if contains(keys(local.cloudfront_managed_origin_request_policy_ids_by_name), name)
    },
    {
      for name, policy in data.aws_cloudfront_origin_request_policy.by_name :
      name => policy.id
    }
  )

  cloudfront_response_headers_policy_ids_by_name = merge(
    {
      for name in local.cloudfront_response_headers_policy_names :
      name => local.cloudfront_managed_response_headers_policy_ids_by_name[name]
      if contains(keys(local.cloudfront_managed_response_headers_policy_ids_by_name), name)
    },
    {
      for name, policy in data.aws_cloudfront_response_headers_policy.by_name :
      name => policy.id
    }
  )
}

resource "aws_cloudfront_origin_access_control" "managed" {
  for_each = local.cloudfront_origin_access_controls

  name                              = each.value.name
  description                       = try(each.value.description, null)
  origin_access_control_origin_type = try(each.value.origin_type, "s3")
  signing_behavior                  = try(each.value.signing_behavior, "always")
  signing_protocol                  = try(each.value.signing_protocol, "sigv4")
}

resource "aws_cloudfront_function" "managed" {
  for_each = local.cloudfront_functions

  name    = each.value.name
  runtime = try(each.value.runtime, "cloudfront-js-1.0")
  comment = try(each.value.comment, null)
  publish = try(each.value.publish, true)
  code = try(each.value.code_file, null) == null ? each.value.code : file(
    startswith(tostring(each.value.code_file), "/") ?
    tostring(each.value.code_file) :
    "${path.root}/${tostring(each.value.code_file)}"
  )
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
  web_acl_id = try(coalesce(
    try(each.value.web_acl_arn, null),
    (
      coalesce(
        try(each.value.web_acl_name, null),
        try(each.value.web_acl_id, null),
        try(each.value.web_acl, null)
        ) == null ? null : lookup(
        var.waf_web_acl_arns_by_name,
        coalesce(
          try(each.value.web_acl_name, null),
          try(each.value.web_acl_id, null),
          try(each.value.web_acl, null)
        ),
        coalesce(
          try(each.value.web_acl_name, null),
          try(each.value.web_acl_id, null),
          try(each.value.web_acl, null)
        )
      )
    )
  ), null)

  dynamic "origin" {
    for_each = try(each.value.origins, [])

    content {
      domain_name = lookup(
        local.cloudfront_origin_domain_names_by_reference,
        tostring(origin.value.domain_name),
        tostring(origin.value.domain_name)
      )
      origin_id   = origin.value.id
      origin_path = try(origin.value.origin_path, null)
      origin_access_control_id = try(coalesce(
        try(origin.value.origin_access_control_id, null),
        (
          coalesce(
            try(origin.value.origin_access_control_name, null),
            try(origin.value.origin_access_control, null)
            ) == null ? null : lookup(
            local.cloudfront_oac_ids_by_name,
            tostring(coalesce(
              try(origin.value.origin_access_control_name, null),
              try(origin.value.origin_access_control, null)
            )),
            tostring(coalesce(
              try(origin.value.origin_access_control_name, null),
              try(origin.value.origin_access_control, null)
            ))
          )
        )
      ), null)

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
    target_origin_id = lookup(
      lookup(local.cloudfront_origin_ids_by_distribution, each.key, {}),
      tostring(coalesce(
        try(each.value.default_cache_behavior.target_origin_id, null),
        try(each.value.default_cache_behavior.target_origin_name, null),
        try(each.value.default_cache_behavior.target_origin, null)
      )),
      tostring(coalesce(
        try(each.value.default_cache_behavior.target_origin_id, null),
        try(each.value.default_cache_behavior.target_origin_name, null),
        try(each.value.default_cache_behavior.target_origin, null)
      ))
    )
    viewer_protocol_policy = try(each.value.default_cache_behavior.viewer_protocol_policy, "redirect-to-https")
    allowed_methods        = try(each.value.default_cache_behavior.allowed_methods, ["GET", "HEAD", "OPTIONS"])
    cached_methods         = try(each.value.default_cache_behavior.cached_methods, ["GET", "HEAD"])
    compress               = try(each.value.default_cache_behavior.compress, true)

    cache_policy_id = try(coalesce(
      try(each.value.default_cache_behavior.cache_policy_id, null),
      lookup(
        local.cloudfront_cache_policy_ids_by_name,
        try(trimspace(each.value.default_cache_behavior.cache_policy_name), ""),
        null
      )
    ), null)
    origin_request_policy_id = try(coalesce(
      try(each.value.default_cache_behavior.origin_request_policy_id, null),
      lookup(
        local.cloudfront_origin_request_policy_ids_by_name,
        try(trimspace(each.value.default_cache_behavior.origin_request_policy_name), ""),
        null
      )
    ), null)
    response_headers_policy_id = try(coalesce(
      try(each.value.default_cache_behavior.response_headers_policy_id, null),
      lookup(
        local.cloudfront_response_headers_policy_ids_by_name,
        try(trimspace(each.value.default_cache_behavior.response_headers_policy_name), ""),
        null
      )
    ), null)

    dynamic "forwarded_values" {
      for_each = try(coalesce(
        try(each.value.default_cache_behavior.cache_policy_id, null),
        lookup(
          local.cloudfront_cache_policy_ids_by_name,
          try(trimspace(each.value.default_cache_behavior.cache_policy_name), ""),
          null
        )
      ), null) == null ? [1] : []

      content {
        query_string = true
        cookies {
          forward = "all"
        }
      }
    }

    dynamic "function_association" {
      for_each = try(each.value.default_cache_behavior.function_associations, [])

      content {
        event_type = try(function_association.value.event_type, "viewer-request")
        function_arn = lookup(
          local.cloudfront_function_arns_by_name,
          tostring(coalesce(
            try(function_association.value.function_name, null),
            try(function_association.value.function_arn, null),
            ""
          )),
          tostring(coalesce(
            try(function_association.value.function_arn, null),
            try(function_association.value.function_name, null),
            ""
          ))
        )
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = try(each.value.cache_behaviors, [])

    content {
      path_pattern = ordered_cache_behavior.value.path_pattern
      target_origin_id = lookup(
        lookup(local.cloudfront_origin_ids_by_distribution, each.key, {}),
        tostring(coalesce(
          try(ordered_cache_behavior.value.target_origin_id, null),
          try(ordered_cache_behavior.value.target_origin_name, null),
          try(ordered_cache_behavior.value.target_origin, null)
        )),
        tostring(coalesce(
          try(ordered_cache_behavior.value.target_origin_id, null),
          try(ordered_cache_behavior.value.target_origin_name, null),
          try(ordered_cache_behavior.value.target_origin, null)
        ))
      )
      viewer_protocol_policy = try(ordered_cache_behavior.value.viewer_protocol_policy, "redirect-to-https")
      allowed_methods        = try(ordered_cache_behavior.value.allowed_methods, ["GET", "HEAD", "OPTIONS"])
      cached_methods         = try(ordered_cache_behavior.value.cached_methods, ["GET", "HEAD"])
      compress               = try(ordered_cache_behavior.value.compress, true)

      cache_policy_id = try(coalesce(
        try(ordered_cache_behavior.value.cache_policy_id, null),
        lookup(
          local.cloudfront_cache_policy_ids_by_name,
          try(trimspace(ordered_cache_behavior.value.cache_policy_name), ""),
          null
        )
      ), null)
      origin_request_policy_id = try(coalesce(
        try(ordered_cache_behavior.value.origin_request_policy_id, null),
        lookup(
          local.cloudfront_origin_request_policy_ids_by_name,
          try(trimspace(ordered_cache_behavior.value.origin_request_policy_name), ""),
          null
        )
      ), null)
      response_headers_policy_id = try(coalesce(
        try(ordered_cache_behavior.value.response_headers_policy_id, null),
        lookup(
          local.cloudfront_response_headers_policy_ids_by_name,
          try(trimspace(ordered_cache_behavior.value.response_headers_policy_name), ""),
          null
        )
      ), null)

      dynamic "forwarded_values" {
        for_each = try(coalesce(
          try(ordered_cache_behavior.value.cache_policy_id, null),
          lookup(
            local.cloudfront_cache_policy_ids_by_name,
            try(trimspace(ordered_cache_behavior.value.cache_policy_name), ""),
            null
          )
        ), null) == null ? [1] : []

        content {
          query_string = true
          cookies {
            forward = "all"
          }
        }
      }

      dynamic "function_association" {
        for_each = try(ordered_cache_behavior.value.function_associations, [])

        content {
          event_type = try(function_association.value.event_type, "viewer-request")
          function_arn = lookup(
            local.cloudfront_function_arns_by_name,
            tostring(coalesce(
              try(function_association.value.function_name, null),
              try(function_association.value.function_arn, null),
              ""
            )),
            tostring(coalesce(
              try(function_association.value.function_arn, null),
              try(function_association.value.function_name, null),
              ""
            ))
          )
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
    acm_certificate_arn            = lookup(local.cloudfront_viewer_certificate_arns_by_distribution, each.key, null)
    ssl_support_method             = try(each.value.viewer_certificate.ssl_support_method, null)
    minimum_protocol_version       = try(each.value.viewer_certificate.minimum_protocol_version, "TLSv1.2_2021")
    cloudfront_default_certificate = lookup(local.cloudfront_viewer_certificate_arns_by_distribution, each.key, null) == null
  }

  dynamic "logging_config" {
    for_each = try(each.value.logging.enabled, false) ? [each.value.logging] : []

    content {
      bucket          = logging_config.value.bucket
      include_cookies = try(logging_config.value.include_cookies, false)
      prefix          = try(logging_config.value.prefix, null)
    }
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}
