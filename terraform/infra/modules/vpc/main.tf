################################################################################
# VPC Module
################################################################################
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs_num  = length(data.aws_availability_zones.available) >= 2 ? 2 : length(data.aws_availability_zones.available)
  azs      = slice(data.aws_availability_zones.available.names, 0, local.azs_num)
  vpc_cidr = var.vpc_cidr
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = var.vpc_name
  cidr = local.vpc_cidr

  providers = {
    aws = aws.eu-west-1
  }

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 2)]

  enable_nat_gateway = true
  single_nat_gateway = true
  create_igw         = true # this is the default

  # These tags are needed for aws load balancer controller 
  # auto subnet discovery of public/private subnets 
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Terraform   = "true"
    Environment = "jifiti-devops"
  }
}


