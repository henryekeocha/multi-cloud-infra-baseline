################################################################################
# GCP VPC Module — Variables
################################################################################

variable "project_id" {
  description = "The GCP project ID in which resources will be created."
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network. Used as a prefix for all child resources."
  type        = string
}

variable "description" {
  description = "Human-readable description of the VPC network."
  type        = string
  default     = "Managed by Terraform"
}

variable "routing_mode" {
  description = "Network-wide routing mode. REGIONAL keeps route advertisements regional; GLOBAL advertises all subnets to all regions."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "routing_mode must be REGIONAL or GLOBAL."
  }
}

variable "mtu" {
  description = "Maximum Transmission Unit in bytes. 1460 (default) or 1500 (jumbo frames for GKE Dataplane V2)."
  type        = number
  default     = 1460

  validation {
    condition     = contains([1460, 1500], var.mtu)
    error_message = "mtu must be 1460 or 1500."
  }
}

variable "delete_default_routes_on_create" {
  description = "If true, delete the default internet gateway route upon VPC creation. Recommended for private-only networks."
  type        = bool
  default     = false
}

###############################################################################
# Subnets
###############################################################################

variable "subnets" {
  description = <<-EOT
    List of subnet definitions. Each object supports:
      - name                    (required) subnet name
      - region                  (required) GCP region
      - cidr                    (required) primary CIDR block
      - private_google_access   (optional, default true) enable Private Google Access
      - private_ipv6_google_access (optional) IPv6 Google Access setting
      - flow_log_interval       (optional) aggregation interval for flow logs
      - flow_log_sampling       (optional, 0-1) fraction of flows to sample
      - flow_log_metadata       (optional) metadata inclusion setting
      - description             (optional) human-readable description
      - secondary_ranges        (optional) list of {range_name, cidr} for GKE
  EOT
  type        = any
  default     = []

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet must be defined."
  }
}

###############################################################################
# Cloud Router / NAT
###############################################################################

variable "router_asn" {
  description = "BGP ASN for Cloud Router instances. Use a private ASN in range 64512-65534."
  type        = number
  default     = 64514
}

variable "enable_nat" {
  description = "Whether to provision Cloud NAT in each region for private egress."
  type        = bool
  default     = true
}

variable "nat_min_ports_per_vm" {
  description = "Minimum number of NAT ports reserved per VM. Higher values reduce SNAT port exhaustion."
  type        = number
  default     = 64
}

###############################################################################
# Firewall
###############################################################################

variable "create_default_deny_rules" {
  description = "Create default-deny ingress and egress firewall rules (CKV_GCP_88). Recommended true for all environments."
  type        = bool
  default     = true
}

variable "allow_iap_ssh" {
  description = "Allow SSH access via Identity-Aware Proxy (IAP). Avoids exposing SSH to the public internet."
  type        = bool
  default     = true
}

variable "allow_lb_health_checks" {
  description = "Allow ingress from Google Cloud load balancer health-check IP ranges."
  type        = bool
  default     = true
}

variable "firewall_rules" {
  description = <<-EOT
    List of custom firewall rule objects. Each object supports:
      - name              (required)
      - direction         (optional, default INGRESS)
      - priority          (optional, default 1000)
      - description       (optional)
      - allow             (optional) list of {protocol, ports}
      - deny              (optional) list of {protocol, ports}
      - source_ranges     (optional)
      - destination_ranges (optional)
      - target_tags       (optional)
      - source_tags       (optional)
  EOT
  type        = any
  default     = []
}

###############################################################################
# DNS
###############################################################################

variable "enable_dns_logging" {
  description = "Enable Cloud DNS query logging for the VPC. Required for SOC2 / HIPAA audit trails."
  type        = bool
  default     = true
}
