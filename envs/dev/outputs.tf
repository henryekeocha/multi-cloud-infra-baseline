output "aws_vpc_id" {
  description = "AWS VPC ID."
  value       = module.aws_vpc.vpc_id
}

output "aws_private_subnet_ids" {
  description = "AWS private subnet IDs."
  value       = module.aws_vpc.private_subnet_ids
}

output "gcp_vpc_name" {
  description = "GCP VPC name."
  value       = module.gcp_vpc.vpc_name
}

output "gcp_subnet_self_links" {
  description = "GCP subnet self_links for GKE node pool attachment."
  value       = module.gcp_vpc.subnet_self_links
}
