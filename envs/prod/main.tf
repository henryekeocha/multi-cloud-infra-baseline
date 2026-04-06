################################################################################
# Prod Environment — Root Module
#
# Full HA configuration: NAT GW per AZ, 90-day log retention, tighter CIDRs.
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
    # bucket         = "my-org-tf-state"
    # key            = "multi-cloud-infra/prod/terraform.tfstate"
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
  env = "prod"

  common_tags = {
    Environment = local.env
    Project     = "multi-cloud-infra-baseline"
    ManagedBy   = "Terraform"
    Owner       = "platform-engineering"
    CostCenter  = "infra-platform"
  }
}

###############################################################################
# AWS VPC — Production
###############################################################################

module "aws_vpc" {
  source = "../../modules/aws/vpc"

  aws_region  = var.aws_region
  vpc_name    = "${local.env}-vpc"
  vpc_cidr    = "10.50.0.0/16"

  public_subnet_cidrs  = ["10.50.0.0/24", "10.50.1.0/24", "10.50.2.0/24"]
  private_subnet_cidrs = ["10.50.10.0/24", "10.50.11.0/24", "10.50.12.0/24"]
  data_subnet_cidrs    = ["10.50.20.0/24", "10.50.21.0/24", "10.50.22.0/24"]

  enable_nat_gateway      = true
  single_nat_gateway      = false  # HA: one NAT GW per AZ
  flow_log_retention_days = 90     # 90-day retention for HIPAA

  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  tags = local.common_tags
}

###############################################################################
# GCP VPC — Production
###############################################################################

module "gcp_vpc" {
  source = "../../modules/gcp/vpc"

  project_id = var.gcp_project_id
  vpc_name   = "${local.env}-vpc"

  subnets = [
    {
      name   = "${local.env}-app-${var.gcp_region}"
      region = var.gcp_region
      cidr   = "10.51.0.0/20"
      # GKE secondary ranges — /14 pods, /20 services (Google recommended sizing)
      secondary_ranges = [
        { range_name = "pods", cidr = "10.200.0.0/14" },
        { range_name = "services", cidr = "10.204.0.0/20" },
      ]
    },
    {
      name   = "${local.env}-data-${var.gcp_region}"
      region = var.gcp_region
      cidr   = "10.51.16.0/20"
    },
  ]

  enable_nat                = true
  allow_iap_ssh             = true
  allow_lb_health_checks    = true
  enable_dns_logging        = true
  create_default_deny_rules = true
  nat_min_ports_per_vm      = 128  # higher for prod to reduce SNAT exhaustion
}
