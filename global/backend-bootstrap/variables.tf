variable "org_prefix" {
  description = "Short org identifier used in globally-unique resource names (e.g. 'cvs', 'myorg')."
  type        = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "gcp_tf_service_account" {
  description = "Service account email used by Terraform to manage GCP resources."
  type        = string
}
