################################################################################
# Dev Environment — Root Module
#
# Wires the AWS and GCP VPC modules together for the dev environment.
# Costs are optimised: single NAT GW (AWS), shorter log retention.
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 6.0"
    }
  }

  backend "s3" {
    # Values supplied via -backend-config or environment variables
    # bucket         = "my-org-tf-state"
    # key            = "multi-cloud-infra/dev/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  env = "dev"

  common_tags = {
    Environment = local.env
    Project     = "multi-cloud-infra-baseline"
    ManagedBy   = "Terraform"
    Owner       = "platform-engineering"
  }
}

###############################################################################
# AWS VPC
###############################################################################

module "aws_vpc" {
  source = "../../modules/aws/vpc"

  aws_region  = var.aws_region
  vpc_name    = "${local.env}-vpc"
  vpc_cidr    = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  data_subnet_cidrs    = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway      = true
  single_nat_gateway      = true  # cost optimisation for dev
  flow_log_retention_days = 30    # shorter retention in dev

  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  tags = local.common_tags
}

###############################################################################
# GCP VPC
###############################################################################

module "gcp_vpc" {
  source = "../../modules/gcp/vpc"

  project_id = var.gcp_project_id
  vpc_name   = "${local.env}-vpc"

  subnets = [
    {
      name   = "${local.env}-app-${var.gcp_region}"
      region = var.gcp_region
      cidr   = "10.1.0.0/20"
      secondary_ranges = [
        { range_name = "pods", cidr = "10.100.0.0/16" },
        { range_name = "services", cidr = "10.200.0.0/20" },
      ]
    },
    {
      name   = "${local.env}-data-${var.gcp_region}"
      region = var.gcp_region
      cidr   = "10.1.16.0/20"
    },
  ]

  enable_nat            = true
  allow_iap_ssh         = true
  allow_lb_health_checks = true
  enable_dns_logging    = true
  create_default_deny_rules = true
}
