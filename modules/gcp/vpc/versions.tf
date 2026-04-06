################################################################################
# GCP VPC Module — Provider / Version Constraints
#
# Pinned separately so root modules can override constraints without touching
# module logic.
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 6.0"
    }
  }
}
