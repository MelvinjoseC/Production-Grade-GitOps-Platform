output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the provisioned VPC"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of IDs of private subnets"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of IDs of public subnets"
}

output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "The name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "The endpoint for the EKS Kubernetes API server"
}

output "cluster_security_group_id" {
  value       = aws_security_group.cluster.id
  description = "Security group ID attached to the EKS cluster control plane"
}

output "node_security_group_id" {
  value       = aws_security_group.node.id
  description = "Security group ID attached to the EKS worker nodes"
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.eks.arn
  description = "The ARN of the OIDC Provider for EKS"
}

output "ebs_csi_irsa_role_arn" {
  value       = aws_iam_role.ebs_csi.arn
  description = "The ARN of the IAM Role for EBS CSI driver"
}

output "loki_s3_irsa_role_arn" {
  value       = aws_iam_role.loki_s3.arn
  description = "The ARN of the IAM Role for Loki S3 access"
}

output "cluster_autoscaler_irsa_role_arn" {
  value       = aws_iam_role.cluster_autoscaler.arn
  description = "The ARN of the IAM Role for Kubernetes Cluster Autoscaler"
}

output "vpc_endpoint_s3_id" {
  value       = aws_vpc_endpoint.s3.id
  description = "The ID of the S3 Gateway VPC Endpoint"
}

output "vpc_endpoints_security_group_id" {
  value       = aws_security_group.vpc_endpoints.id
  description = "The security group ID for VPC Interface Endpoints"
}

output "kms_key_arn" {
  value       = aws_kms_key.eks.arn
  description = "The ARN of the KMS key used for EKS Secret and EBS encryption"
}

output "kms_key_alias" {
  value       = aws_kms_alias.eks.name
  description = "The alias of the KMS key"
}


