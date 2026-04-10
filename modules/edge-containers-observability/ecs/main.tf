locals {
  ecs_clusters = {
    for cluster in try(var.resources_by_type.ecs_clusters, []) :
    cluster.name => cluster
  }

  ecs_task_definitions = {
    for task_definition in try(var.resources_by_type.ecs_task_definitions, []) :
    task_definition.family => task_definition
  }

  ecs_services = {
    for service in try(var.resources_by_type.ecs_services, []) :
    service.name => service
  }

  ecs_task_definition_arns_by_family = {
    for family, task_definition in aws_ecs_task_definition.managed :
    family => task_definition.arn
  }

  ecs_autoscaling_services = {
    for service_name, service in local.ecs_services :
    service_name => service if try(service.autoscaling.enabled, false)
  }

  # App Auto Scaling expects cluster name (not ARN) in service/<cluster>/<service>.
  ecs_cluster_names_by_identifier = merge(
    { for name, cluster in aws_ecs_cluster.managed : name => cluster.name },
    { for _, cluster in aws_ecs_cluster.managed : cluster.id => cluster.name },
    { for _, cluster in aws_ecs_cluster.managed : cluster.arn => cluster.name }
  )
}

resource "aws_ecs_cluster" "managed" {
  for_each = local.ecs_clusters

  name = each.value.name

  setting {
    name  = "containerInsights"
    value = try(each.value.container_insights, false) ? "enabled" : "disabled"
  }

  dynamic "configuration" {
    for_each = try(each.value.execute_command_configuration.enabled, false) ? [each.value.execute_command_configuration] : []

    content {
      execute_command_configuration {
        kms_key_id = try(configuration.value.kms_key_id, null)
        logging    = try(configuration.value.logging, "DEFAULT")

        dynamic "log_configuration" {
          for_each = try(configuration.value.log_group_name, null) == null ? [] : [1]

          content {
            cloud_watch_log_group_name = configuration.value.log_group_name
          }
        }
      }
    }
  }

  tags = try(each.value.tags, {})
}

resource "aws_ecs_task_definition" "managed" {
  for_each = local.ecs_task_definitions

  family                   = each.value.family
  cpu                      = try(each.value.cpu, null)
  memory                   = try(each.value.memory, null)
  network_mode             = try(each.value.network_mode, null)
  requires_compatibilities = try(each.value.requires_compatibilities, null)
  execution_role_arn       = try(each.value.execution_role_arn, null)
  task_role_arn            = try(each.value.task_role_arn, null)

  dynamic "runtime_platform" {
    for_each = try(each.value.runtime_platform, null) == null ? [] : [each.value.runtime_platform]

    content {
      cpu_architecture        = try(runtime_platform.value.cpu_architecture, null)
      operating_system_family = try(runtime_platform.value.operating_system_family, null)
    }
  }

  dynamic "ephemeral_storage" {
    for_each = try(each.value.ephemeral_storage, null) == null ? [] : [each.value.ephemeral_storage]

    content {
      size_in_gib = try(ephemeral_storage.value.size_in_gib, 21)
    }
  }

  dynamic "volume" {
    for_each = try(each.value.volumes, [])

    content {
      name      = volume.value.name
      host_path = try(volume.value.host_path, null)
    }
  }

  container_definitions = jsonencode([
    for container in try(each.value.container_definitions, []) : {
      name      = container.name
      image     = container.image
      essential = try(container.essential, true)
      portMappings = [
        for port_mapping in try(container.port_mappings, []) : {
          containerPort = try(port_mapping.container_port, null)
          protocol      = try(port_mapping.protocol, "tcp")
        }
      ]
      environment = [
        for env in try(container.environment, []) : {
          name  = env.name
          value = env.value
        }
      ]
      secrets = [
        for secret in try(container.secrets, []) : {
          name      = secret.name
          valueFrom = secret.value_from
        }
      ]
      logConfiguration = try(container.log_configuration, null) == null ? null : {
        logDriver = try(container.log_configuration.log_driver, "awslogs")
        options   = try(container.log_configuration.options, {})
      }
    }
  ])

  tags = try(each.value.tags, {})
}

resource "aws_ecs_service" "managed" {
  for_each = local.ecs_services

  name             = each.value.name
  cluster          = lookup({ for name, cluster in aws_ecs_cluster.managed : name => cluster.id }, each.value.cluster, each.value.cluster)
  task_definition  = lookup(local.ecs_task_definition_arns_by_family, each.value.task_definition_family, each.value.task_definition_family)
  launch_type      = try(each.value.launch_type, "FARGATE")
  platform_version = try(each.value.platform_version, null)
  desired_count    = try(each.value.desired_count, 1)

  enable_execute_command            = try(each.value.enable_execute_command, false)
  health_check_grace_period_seconds = try(each.value.health_check_grace_period_seconds, null)
  force_new_deployment              = try(each.value.force_new_deployment, false)

  deployment_minimum_healthy_percent = try(each.value.deployment.minimum_healthy_percent, null)
  deployment_maximum_percent         = try(each.value.deployment.maximum_percent, null)

  dynamic "deployment_circuit_breaker" {
    for_each = try(each.value.deployment.circuit_breaker, null) == null ? [] : [each.value.deployment.circuit_breaker]

    content {
      enable   = try(deployment_circuit_breaker.value.enable, true)
      rollback = try(deployment_circuit_breaker.value.rollback, true)
    }
  }

  dynamic "deployment_controller" {
    for_each = try(each.value.deployment_controller, null) == null ? [] : [each.value.deployment_controller]

    content {
      type = deployment_controller.value
    }
  }

  dynamic "network_configuration" {
    for_each = try(each.value.network_configuration, null) == null ? [] : [each.value.network_configuration]

    content {
      subnets = [
        for subnet in try(network_configuration.value.subnets, []) :
        lookup(var.subnet_ids_by_name, subnet, subnet)
      ]

      security_groups = [
        for security_group in try(network_configuration.value.security_groups, []) :
        lookup(var.security_group_ids_by_name, security_group, security_group)
      ]

      assign_public_ip = try(network_configuration.value.assign_public_ip, false)
    }
  }

  dynamic "load_balancer" {
    for_each = try(each.value.load_balancer, null) == null ? [] : [each.value.load_balancer]

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  tags = try(each.value.tags, {})
}

resource "aws_appautoscaling_target" "ecs_service" {
  for_each = local.ecs_autoscaling_services

  max_capacity       = try(each.value.autoscaling.max_capacity, 10)
  min_capacity       = try(each.value.autoscaling.min_capacity, 1)
  resource_id        = "service/${lookup(local.ecs_cluster_names_by_identifier, each.value.cluster, each.value.cluster)}/${each.value.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_service_cpu" {
  for_each = {
    for service_name, service in local.ecs_autoscaling_services :
    service_name => service if try(service.autoscaling.cpu_target, null) != null
  }

  name               = "${each.value.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = each.value.autoscaling.cpu_target
  }
}

resource "aws_appautoscaling_policy" "ecs_service_memory" {
  for_each = {
    for service_name, service in local.ecs_autoscaling_services :
    service_name => service if try(service.autoscaling.memory_target, null) != null
  }

  name               = "${each.value.name}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = each.value.autoscaling.memory_target
  }
}
