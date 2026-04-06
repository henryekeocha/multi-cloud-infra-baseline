################################################################################
# GCP VPC Module — Outputs
################################################################################

output "vpc_id" {
  description = "The resource ID (self_link) of the VPC network."
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "The URI of the VPC network, used for cross-module references."
  value       = google_compute_network.vpc.self_link
}

output "vpc_gateway_ipv4" {
  description = "The gateway IPv4 address of the VPC."
  value       = google_compute_network.vpc.gateway_ipv4
}

output "subnet_ids" {
  description = "Map of subnet name → subnet ID (self_link)."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Map of subnet name → subnet self_link, used when attaching GKE node pools."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "subnet_cidr_blocks" {
  description = "Map of subnet name → primary CIDR block."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range }
}

output "subnet_regions" {
  description = "Map of subnet name → region."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.region }
}

output "router_ids" {
  description = "Map of region → Cloud Router ID."
  value       = { for k, v in google_compute_router.routers : k => v.id }
}

output "nat_ids" {
  description = "Map of region → Cloud NAT ID. Empty if enable_nat = false."
  value       = { for k, v in google_compute_router_nat.nats : k => v.id }
}

output "firewall_deny_ingress_id" {
  description = "ID of the default-deny ingress firewall rule (null if create_default_deny_rules = false)."
  value       = var.create_default_deny_rules ? google_compute_firewall.deny_all_ingress[0].id : null
}

output "firewall_deny_egress_id" {
  description = "ID of the default-deny egress firewall rule (null if create_default_deny_rules = false)."
  value       = var.create_default_deny_rules ? google_compute_firewall.deny_all_egress[0].id : null
}
