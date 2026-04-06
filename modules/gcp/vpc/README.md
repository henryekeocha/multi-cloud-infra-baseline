# GCP VPC Terraform Module

Provisions a production-grade GCP custom-mode VPC with regional subnets, Cloud Router, Cloud NAT, and hardened firewall rules.

## Features

- **Custom-mode VPC** — no auto-created subnets; full CIDR control
- **Regional subnets** with optional secondary IP ranges for GKE Pod/Service CIDRs
- **Private Google Access** enabled by default — no public IPs needed for GCP APIs
- **VPC Flow Logs** always enabled per subnet — satisfies CKV_GCP_26, HIPAA §164.312(b)
- **Cloud Router + NAT** per region — secure private egress without public IPs
- **Default-deny firewall** — explicit allow rules only (CKV_GCP_88)
- **IAP-only SSH** — eliminates direct SSH exposure from the internet
- **DNS query logging** — full audit trail for HIPAA/SOC2

## Usage

```hcl
module "gcp_vpc" {
  source = "../../modules/gcp/vpc"

  project_id = "my-project-id"
  vpc_name   = "prod-vpc"

  subnets = [
    {
      name   = "prod-app-us-central1"
      region = "us-central1"
      cidr   = "10.10.0.0/20"
      secondary_ranges = [
        { range_name = "pods",     cidr = "10.100.0.0/16" },
        { range_name = "services", cidr = "10.200.0.0/20" },
      ]
    },
    {
      name   = "prod-data-us-central1"
      region = "us-central1"
      cidr   = "10.10.16.0/20"
    },
  ]

  enable_nat         = true
  allow_iap_ssh      = true
  enable_dns_logging = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_id` | GCP project ID | `string` | — | yes |
| `vpc_name` | VPC name (resource prefix) | `string` | — | yes |
| `subnets` | List of subnet definitions | `any` | — | yes |
| `routing_mode` | REGIONAL or GLOBAL | `string` | `REGIONAL` | no |
| `enable_nat` | Provision Cloud NAT per region | `bool` | `true` | no |
| `create_default_deny_rules` | Default-deny firewall rules | `bool` | `true` | no |
| `allow_iap_ssh` | Allow SSH via IAP only | `bool` | `true` | no |
| `allow_lb_health_checks` | Allow GCP LB health-check probes | `bool` | `true` | no |
| `enable_dns_logging` | Cloud DNS query logging | `bool` | `true` | no |
| `firewall_rules` | Custom firewall rule list | `any` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC resource ID |
| `vpc_self_link` | VPC URI for cross-module references |
| `subnet_ids` | Map of subnet name → ID |
| `subnet_self_links` | Map of subnet name → self_link |
| `subnet_cidr_blocks` | Map of subnet name → CIDR |
| `router_ids` | Map of region → Cloud Router ID |
| `nat_ids` | Map of region → Cloud NAT ID |

## Security Controls Satisfied

| Control | Mechanism |
|---------|-----------|
| CKV_GCP_26 | VPC Flow Logs enabled on all subnets |
| CKV_GCP_74 | Private Google Access enabled |
| CKV_GCP_88 | Default-deny ingress + egress firewall rules |
| CKV_GCP_2  | No SSH open to 0.0.0.0/0 — IAP only |
| CKV_GCP_77 | DNS query logging enabled |
