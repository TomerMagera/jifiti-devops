################################################################################
# General Variables from root module
################################################################################
variable "profile" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "CIDR of the created VPC"
}

variable "vpc_name" {
  type = string
  default = "jifiti-devops-vpc"
}
