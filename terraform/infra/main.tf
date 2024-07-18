################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "./modules/vpc"

  region   = var.region
  profile  = var.aws_profile
  vpc_cidr = var.vpc_cidr
  # enable_dns_support   = true
  # enable_dns_hostnames = true
}

################################################################################
# EKS Cluster Module
################################################################################

module "eks" {
  source = "./modules/eks-cluster"

  region  = var.region
  profile = var.aws_profile
  rolearn = var.rolearn

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnets    = module.vpc.private_subnets
  eks_instance_types = var.eks_instance_types
}

################################################################################
# AWS ALB Controller
################################################################################

module "aws_alb_controller" {
  source = "./modules/aws-alb-controller"

  region       = var.region
  env_name     = var.environment
  cluster_name = var.cluster_name

  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
}

