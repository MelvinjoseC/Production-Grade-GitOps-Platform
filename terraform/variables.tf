variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources into"
  default     = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Target deployment environment"
  default     = "production"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to distribute subnets"
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "gitops-eks-prod"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes control plane version"
  default     = "1.30"
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string # ON_DEMAND or SPOT
  }))
  description = "Configuration for EKS managed node groups"
  default = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
    }
    workload = {
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 10
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
    }
  }
}
