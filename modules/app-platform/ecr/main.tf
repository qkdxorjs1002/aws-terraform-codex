locals {
  ecr_repositories = {
    for repository in try(var.resources_by_type.ecr_repositories, []) :
    repository.name => repository
  }
}

resource "aws_ecr_repository" "managed" {
  for_each = local.ecr_repositories

  name                 = each.value.name
  image_tag_mutability = try(each.value.image_tag_mutability, "IMMUTABLE")
  force_delete         = try(each.value.force_delete, false)

  image_scanning_configuration {
    scan_on_push = try(each.value.scan_on_push, true)
  }

  encryption_configuration {
    encryption_type = try(each.value.encryption_configuration.encryption_type, "AES256")
    kms_key         = try(each.value.encryption_configuration.kms_key, null)
  }

  tags = merge(
    {
      Name = each.value.name
    },
    try(each.value.tags, {})
  )
}

resource "aws_ecr_repository_policy" "managed" {
  for_each = {
    for name, repository in local.ecr_repositories :
    name => repository if try(repository.repository_policy, "") != ""
  }

  repository = aws_ecr_repository.managed[each.key].name
  policy     = each.value.repository_policy
}

resource "aws_ecr_lifecycle_policy" "managed" {
  for_each = {
    for name, repository in local.ecr_repositories :
    name => repository if try(repository.lifecycle_policy, "") != ""
  }

  repository = aws_ecr_repository.managed[each.key].name
  policy     = each.value.lifecycle_policy
}
