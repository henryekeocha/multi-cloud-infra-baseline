################################################################################
# Backend Bootstrap — Run Once
#
# Creates the S3 + DynamoDB backend for Terraform remote state (AWS) and
# the GCS bucket (GCP). Run with local state first, then migrate:
#
#   terraform init
#   terraform apply
#   # Add backend "s3" block to each env, then:
#   terraform init -migrate-state
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
}

provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

###############################################################################
# AWS — S3 State Bucket
###############################################################################

resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.org_prefix}-tf-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name      = "Terraform Remote State"
    ManagedBy = "Terraform"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_state_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name      = "Terraform State Lock"
    ManagedBy = "Terraform"
  }
}

###############################################################################
# GCP — GCS State Bucket
###############################################################################

resource "google_storage_bucket" "tf_state" {
  name          = "${var.org_prefix}-tf-state-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  lifecycle_rule {
    action { type = "Delete" }
    condition { num_newer_versions = 10 }
  }
}

resource "google_storage_bucket_iam_binding" "tf_state_admin" {
  bucket = google_storage_bucket.tf_state.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${var.gcp_tf_service_account}",
  ]
}
