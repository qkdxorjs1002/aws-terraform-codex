output "name" {
  value = aws_eks_node_group.this.node_group_name
}

output "arn" {
  value = aws_eks_node_group.this.arn
}

output "status" {
  value = aws_eks_node_group.this.status
}
