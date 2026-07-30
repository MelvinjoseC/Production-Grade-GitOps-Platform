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

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "The vpc_cidr value must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to distribute subnets"
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Set to true to provision a single shared NAT Gateway for cost-efficiency. Set to false to provision a NAT Gateway per Availability Zone for production-grade high availability."
  default     = false
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

  validation {
    condition     = contains(["1.28", "1.29", "1.30", "1.31"], var.cluster_version)
    error_message = "The cluster_version must be a supported EKS Kubernetes version: 1.28, 1.29, 1.30, or 1.31."
  }
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
