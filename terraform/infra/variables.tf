
################################################################################
# Default Variables
################################################################################

variable "aws_profile" {
  description = "Main AWS profile to use"
  default     = "jifiti-devops"
  type        = string
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "CIDR of the created VPC"
}


################################################################################
# EKS Cluster Variables
################################################################################

variable "cluster_name" {
  type    = string
  default = "jifiti-devops-cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "eks_instance_types" {
  type        = list(string)
  default     = ["t3.small"]
  description = "Instance types for EKS nodes"
}

variable "rolearn" {
  description = "Add admin role to the aws-auth configmap"
  type        = string
  default     = null
}

################################################################################
# ALB Controller Variables
################################################################################

variable "environment" {
  type        = string
  default     = "jifiti-devops"
  description = "environment name"
}