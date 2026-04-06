variable "aws_region" {
  description = "AWS region for prod environment."
  type        = string
  default     = "us-east-1"
}

variable "gcp_project_id" {
  description = "GCP project ID for prod environment."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for prod environment."
  type        = string
  default     = "us-central1"
}
