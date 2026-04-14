output "name" {
  value = aws_eks_cluster.this.name
}

output "arn" {
  value = aws_eks_cluster.this.arn
}

output "endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "version" {
  value = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
