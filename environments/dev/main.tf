# Main Terraform configuration for the development environment networking module
locals {
  common_tags = {
    Owner = "DevOps"
    Lab   = "terraform-networking"
  }
}

# Network module configuration for the development environment
module "network" {
  source = "../../modules/network"

  name = "arrise-${var.environment}"

  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
  enable_nat_gateway  = true

  tags = local.common_tags
}

# Security module configuration for the development environment
module "security" {
  source = "../../modules/security"

  name   = "arrise-${var.environment}"
  vpc_id = module.network.vpc_id

  tags = local.common_tags
}