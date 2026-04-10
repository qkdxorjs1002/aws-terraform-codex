output "arn" {
  value = aws_eks_addon.this.arn
}

output "version" {
  value = aws_eks_addon.this.addon_version
}
