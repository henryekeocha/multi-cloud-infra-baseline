################################################################################
# GCP VPC Module — Main
#
# Creates a custom-mode VPC with regional subnets, secondary IP ranges for
# GKE Pod/Service CIDRs, Cloud Router + NAT for private egress, and
# hierarchical firewall rules. Mirrors the project's AWS VPC module structure.
#
# Reference: https://registry.terraform.io/providers/hashicorp/google/latest
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

###############################################################################
# VPC Network
###############################################################################

resource "google_compute_network" "vpc" {
  name                            = var.vpc_name
  project                         = var.project_id
  description                     = var.description
  auto_create_subnetworks         = false # custom-mode only
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = var.delete_default_routes_on_create
  mtu                             = var.mtu

  # Shared-VPC host project support
  # Enabled externally via google_compute_shared_vpc_host_project resource
}

###############################################################################
# Subnets
###############################################################################

resource "google_compute_subnetwork" "subnets" {
  for_each = { for s in var.subnets : s.name => s }

  name                     = each.value.name
  project                  = var.project_id
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = lookup(each.value, "private_google_access", true)
  description              = lookup(each.value, "description", null)

  # Private Service Connect / VPC Service Controls
  private_ipv6_google_access = lookup(each.value, "private_ipv6_google_access", "DISABLE_GOOGLE_ACCESS")

  # Flow logs — always on for security posture (Checkov CKV_GCP_26)
  log_config {
    aggregation_interval = lookup(each.value, "flow_log_interval", "INTERVAL_5_SEC")
    flow_sampling        = lookup(each.value, "flow_log_sampling", 0.5)
    metadata             = lookup(each.value, "flow_log_metadata", "INCLUDE_ALL_METADATA")
  }

  # Secondary IP ranges (GKE Pods / Services)
  dynamic "secondary_ip_range" {
    for_each = lookup(each.value, "secondary_ranges", [])
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }
}

###############################################################################
# Cloud Router (per region)
###############################################################################

resource "google_compute_router" "routers" {
  for_each = toset(distinct([for s in var.subnets : s.region]))

  name    = "${var.vpc_name}-router-${each.key}"
  project = var.project_id
  region  = each.key
  network = google_compute_network.vpc.id

  bgp {
    asn               = var.router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

###############################################################################
# Cloud NAT (per router / region)
###############################################################################

resource "google_compute_router_nat" "nats" {
  for_each = var.enable_nat ? toset(distinct([for s in var.subnets : s.region])) : toset([])

  name                               = "${var.vpc_name}-nat-${each.key}"
  project                            = var.project_id
  router                             = google_compute_router.routers[each.key].name
  region                             = each.key
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  min_ports_per_vm                    = var.nat_min_ports_per_vm
  tcp_established_idle_timeout_sec    = 1200
  tcp_transitory_idle_timeout_sec     = 30
  udp_idle_timeout_sec                = 30
  icmp_idle_timeout_sec               = 30
  enable_endpoint_independent_mapping = false
}

###############################################################################
# Firewall Rules
###############################################################################

# Deny all ingress (default-deny) — CKV_GCP_88
resource "google_compute_firewall" "deny_all_ingress" {
  count = var.create_default_deny_rules ? 1 : 0

  name        = "${var.vpc_name}-deny-all-ingress"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Default-deny all ingress traffic; explicit allow rules override this."
  direction   = "INGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Deny all egress (default-deny) — CKV_GCP_88
resource "google_compute_firewall" "deny_all_egress" {
  count = var.create_default_deny_rules ? 1 : 0

  name        = "${var.vpc_name}-deny-all-egress"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Default-deny all egress traffic; explicit allow rules override this."
  direction   = "EGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow internal VPC traffic
resource "google_compute_firewall" "allow_internal" {
  name        = "${var.vpc_name}-allow-internal"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow all traffic between instances in the VPC."
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [for s in var.subnets : s.cidr]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow SSH from IAP (Identity-Aware Proxy) — no public SSH exposure
resource "google_compute_firewall" "allow_iap_ssh" {
  count = var.allow_iap_ssh ? 1 : 0

  name        = "${var.vpc_name}-allow-iap-ssh"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow SSH via IAP only. No direct SSH from public internet."
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's published IP range — https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = ["35.235.240.0/20"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow health-check probes from Google load balancer IP ranges
resource "google_compute_firewall" "allow_lb_health_checks" {
  count = var.allow_lb_health_checks ? 1 : 0

  name        = "${var.vpc_name}-allow-lb-health-checks"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = "Allow Google Cloud load balancer health-check probes."
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  # GCP load balancer health-check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Custom firewall rules from variable
resource "google_compute_firewall" "custom" {
  for_each = { for r in var.firewall_rules : r.name => r }

  name        = each.value.name
  project     = var.project_id
  network     = google_compute_network.vpc.id
  description = lookup(each.value, "description", null)
  direction   = lookup(each.value, "direction", "INGRESS")
  priority    = lookup(each.value, "priority", 1000)

  dynamic "allow" {
    for_each = lookup(each.value, "allow", [])
    content {
      protocol = allow.value.protocol
      ports    = lookup(allow.value, "ports", null)
    }
  }

  dynamic "deny" {
    for_each = lookup(each.value, "deny", [])
    content {
      protocol = deny.value.protocol
      ports    = lookup(deny.value, "ports", null)
    }
  }

  source_ranges      = lookup(each.value, "source_ranges", null)
  destination_ranges = lookup(each.value, "destination_ranges", null)
  target_tags        = lookup(each.value, "target_tags", null)
  source_tags        = lookup(each.value, "source_tags", null)

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

###############################################################################
# DNS Policy (private DNS logging)
###############################################################################

resource "google_dns_policy" "logging" {
  count = var.enable_dns_logging ? 1 : 0

  name           = "${var.vpc_name}-dns-policy"
  project        = var.project_id
  enable_logging = true

  networks {
    network_url = google_compute_network.vpc.id
  }
}
