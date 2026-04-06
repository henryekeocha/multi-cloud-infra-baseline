# Multi-Cloud Infrastructure Baseline

**Author:** Henry Ekeocha · [henryekeocha.com](https://henryekeocha.com) · [github.com/henryekeocha](https://github.com/henryekeocha)

A Principal Engineer–level proof-of-concept demonstrating production-grade multi-cloud (AWS + GCP) network infrastructure, automated security scanning, and an observability stack. Built as a reference architecture for regulated, high-scale environments.

---

## Problem Statement

Large engineering organisations increasingly operate across multiple cloud providers — driven by requirements for vendor neutrality, regulated data residency, best-of-breed services, and resilience against provider outages. The challenge is doing this *consistently*: the same security posture, the same operational model, and the same developer experience regardless of whether a workload runs in AWS `us-east-1` or GCP `us-central1`.

This repository answers: *what does a principled, repeatable, security-first multi-cloud networking foundation look like in Terraform?*

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     multi-cloud-infra-baseline                  │
│                                                                 │
│  ┌─────────────────────────┐   ┌─────────────────────────────┐ │
│  │   AWS (us-east-1)       │   │   GCP (us-central1)         │ │
│  │                         │   │                             │ │
│  │  VPC: 10.0.0.0/16       │   │  VPC: custom-mode           │ │
│  │  ├── public  /24 × 3AZ  │   │  ├── app subnet /20         │ │
│  │  ├── private /24 × 3AZ  │   │  ├── data subnet /20        │ │
│  │  └── data    /24 × 3AZ  │   │  └── secondary (GKE) CIDRs  │ │
│  │                         │   │                             │ │
│  │  NAT GW × 3 (HA)        │   │  Cloud Router + NAT         │ │
│  │  Flow Logs → CloudWatch │   │  Flow Logs → Cloud Logging  │ │
│  │  S3 + DynamoDB Endpoints│   │  Private Google Access      │ │
│  │  Default SG locked down │   │  Default-deny firewall      │ │
│  └─────────────────────────┘   └─────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CI/CD (GitHub Actions)                                   │  │
│  │  terraform fmt → validate → tflint → checkov → plan      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Observability (Prometheus + Grafana + Alertmanager)      │  │
│  │  Node metrics · Network throughput · Alert rules          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
multi-cloud-infra-baseline/
├── modules/
│   ├── aws/vpc/          ← AWS VPC module (main, variables, outputs, versions)
│   └── gcp/vpc/          ← GCP VPC module (mirrors AWS structure)
├── envs/
│   ├── dev/              ← dev environment root module
│   └── prod/             ← prod environment root module
├── global/
│   └── backend-bootstrap/ ← S3 + DynamoDB / GCS backend setup
├── security/
│   └── checkov-config.yaml
├── monitoring/
│   ├── docker-compose.yml
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   ├── alertmanager.yml
│   │   └── rules/infra-alerts.yml
│   ├── grafana/provisioning/
│   └── dashboards/infra-overview.json
├── .github/workflows/
│   ├── terraform-ci.yml   ← fmt, validate, tflint, plan
│   └── security-scan.yml  ← checkov (SARIF → GitHub Security tab)
├── docs/
│   └── adr-001-multi-cloud-strategy.md
├── Makefile
└── README.md
```

---

## Quick Start

### Prerequisites

- Terraform ≥ 1.5.0
- [tflint](https://github.com/terraform-linters/tflint) ≥ 0.50
- [checkov](https://www.checkov.io/) ≥ 3.0
- Docker + Docker Compose (for local observability stack)

### Run locally

```bash
# Clone and navigate
git clone https://github.com/henryekeocha/multi-cloud-infra-baseline
cd multi-cloud-infra-baseline

# Format + validate all modules
make validate

# Run Checkov security scan
make security-scan

# Spin up observability stack
make monitoring-up
# → Grafana: http://localhost:3000  (admin/admin)
# → Prometheus: http://localhost:9090
```

---

## Security Posture

Security is a first-class citizen, not an afterthought.

| Layer | Control | Implementation |
|---|---|---|
| Network | Default-deny ingress + egress | `google_compute_firewall` deny rules; AWS default SG locked |
| Network | No SSH from 0.0.0.0/0 | GCP: IAP-only SSH; AWS: Systems Manager Session Manager |
| Network | VPC Flow Logs | CloudWatch (AWS) + Cloud Logging (GCP) — all traffic |
| Network | Private egress only | NAT GW (AWS) + Cloud NAT (GCP) — no public IPs on workloads |
| Data | Private Google Access / VPC Endpoints | S3 + DynamoDB Gateway Endpoints; Private Google Access |
| IaC | Policy-as-code | Checkov in CI — HIGH/CRITICAL findings block merge |
| IaC | Provider version pinning | `>= 5.0, < 6.0` — prevents silent breaking changes |
| Audit | DNS query logging | Cloud DNS policy + Route 53 Resolver Logs |
| Audit | API call logging | CloudTrail (AWS) + Cloud Audit Logs (GCP) — enable in envs |

Checkov checks enforced: `CKV_AWS_73`, `CKV_AWS_130`, `CKV_AWS_148`, `CKV_GCP_2`, `CKV_GCP_26`, `CKV_GCP_74`, `CKV_GCP_77`, `CKV_GCP_88`.

---

## Observability Strategy

```
Metrics pipeline:
  Node Exporter → Prometheus (15s scrape) → Grafana dashboards
                                          → Alertmanager → Slack / PagerDuty

Alert tiers:
  CRITICAL  (≥2 min) → PagerDuty + Slack #infra-alerts
  WARNING   (≥5 min) → Slack #infra-warnings

Dashboards:
  infra-overview.json — Fleet health, CPU %, memory %, network throughput, disk usage
```

In production, the same dashboards are deployed via the `kube-prometheus-stack` and `grafana` Helm charts with GitOps (ArgoCD), ensuring the local dev stack and production are always in sync.

---

## Architecture Decision Records

- [ADR-001 — Multi-Cloud Strategy](docs/adr-001-multi-cloud-strategy.md)

---

## Module Reference

### `modules/aws/vpc`

| Variable | Required | Description |
|---|---|---|
| `vpc_name` | ✅ | Name prefix for all resources |
| `aws_region` | ✅ | Deployment region |
| `vpc_cidr` | ✅ | Primary CIDR (e.g. `10.0.0.0/16`) |
| `public_subnet_cidrs` | — | One per AZ; hosts LBs and NAT GW EIPs |
| `private_subnet_cidrs` | — | One per AZ; app tier |
| `data_subnet_cidrs` | — | One per AZ; isolated DB tier |
| `enable_nat_gateway` | — | Default `true` |
| `single_nat_gateway` | — | `true` for dev cost savings |

### `modules/gcp/vpc`

| Variable | Required | Description |
|---|---|---|
| `project_id` | ✅ | GCP project ID |
| `vpc_name` | ✅ | Name prefix for all resources |
| `subnets` | ✅ | List of subnet objects (name, region, cidr) |
| `enable_nat` | — | Default `true` |
| `allow_iap_ssh` | — | Default `true` |
| `enable_dns_logging` | — | Default `true` |

---

## Production Rollout Plan

1. **Bootstrap remote state** — run `global/backend-bootstrap` once per cloud to create S3+DynamoDB / GCS state buckets with versioning and server-side encryption.
2. **Deploy dev** — `terraform apply` in `envs/dev` with `single_nat_gateway = true` to minimise cost.
3. **Run CI gate** — all PRs must pass: `fmt` → `validate` → `tflint` → `checkov` → `plan`.
4. **Promote to prod** — same modules, prod-grade variable values (HA NAT GW, 90-day log retention, CMK encryption).
5. **Enable CloudTrail / Cloud Audit Logs** — configure in environment-level modules for full API audit trail.
6. **Deploy observability** — push `monitoring/` dashboards to kube-prometheus-stack via GitOps. Wire Alertmanager to PagerDuty.
7. **Compliance validation** — run Checkov in scheduled weekly scan; review SARIF output in GitHub Security tab quarterly.

---

## Extending This Baseline

This repo is intentionally scoped to networking + security + observability foundations. Natural next layers:

- **EKS / GKE cluster modules** — referencing `subnet_ids` / `subnet_self_links` outputs
- **Service mesh** — Istio or AWS App Mesh for mTLS between services
- **Secrets management** — AWS Secrets Manager / GCP Secret Manager Terraform modules
- **Azure VNet module** — to complete the three-cloud baseline (follows same pattern)
- **Terratest** — Go-based integration tests for module outputs

---

*Built by Henry Ekeocha — Principal Engineer, Cloud Infrastructure*
