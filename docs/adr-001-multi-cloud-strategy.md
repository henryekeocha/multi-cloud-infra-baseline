# ADR-001 — Multi-Cloud Networking Strategy

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-04-06 |
| **Author** | Henry Ekeocha |
| **Deciders** | Platform Engineering |
| **Supersedes** | N/A (greenfield) |

---

## Context

CVS Health's engineering organisation operates workloads across AWS and GCP. Each cloud was adopted independently, resulting in:

- No shared networking conventions (CIDR allocation, subnet naming, tagging)
- Inconsistent security posture (firewall rules on GCP varied by team; AWS security groups not baseline-reviewed)
- No common observability layer — cloud-native metrics isolated per provider
- Duplicate Terraform code with diverging patterns — raising cognitive load for engineers working cross-cloud

A Principal Engineer–level baseline is needed to establish conventions that teams can fork, extend, and trust.

---

## Decision

Adopt a **modular, convention-over-configuration** approach to multi-cloud networking:

1. **Terraform modules** for each cloud provider follow an identical contract: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`. The variable surface is intentionally parallel — e.g., both modules expose `vpc_name`, subnet definitions, NAT enable/disable, and flow log controls.

2. **Security as a hard gate** — Checkov runs in CI on every PR. HIGH and CRITICAL findings block merge. MEDIUM and LOW are surfaced as warnings. The skip list is intentionally narrow and documented with justification + expiry intent.

3. **Observability is provisioned, not bolted on** — Prometheus alerting rules ship with the repo. Grafana dashboard JSON is version-controlled and provisioned automatically. Alerts route to PagerDuty (CRITICAL) and Slack (WARNING) with inhibition rules to reduce noise.

4. **Default-deny everywhere** — Both cloud modules start from a deny-all posture. Allow rules are explicit and logged. This is non-negotiable in healthcare environments where PHI may traverse the network.

5. **One module, multiple environments** — `envs/dev` and `envs/prod` consume the same modules with different variable values (`single_nat_gateway = true` in dev for cost; `flow_log_retention_days = 365` in prod for compliance).

---

## Alternatives Considered

### A — Cloud-native IaC per provider (CDK for AWS, Deployment Manager for GCP)

**Rejected.** Provider-native tools create a bifurcated skill requirement and prevent cross-cloud reuse. A Terraform-speaking engineer can reason about both providers from a common language. Terraform's state model also gives us a reliable source of truth across both clouds in a single backend.

### B — Terraform Cloud Modules Registry (public modules)

**Rejected as sole source.** Public registry modules (e.g., `terraform-aws-modules/vpc`) are excellent starting points but optimise for breadth over the specific security posture required here. Wrapping them adds an abstraction layer that obscures what Checkov is actually evaluating. This baseline writes modules directly so every resource is visible, auditable, and owned.

### C — Pulumi

**Deferred.** Pulumi's general-purpose language support (TypeScript, Python) is compelling for teams with strong software engineering backgrounds. The ecosystem maturity and enterprise support are not yet at parity with Terraform for large organisations. Revisit in 12 months.

---

## Consequences

### Positive

- Engineers from either cloud background can contribute — the module structure is the same
- New cloud environments (Azure, Oracle Cloud) can follow the same module template
- Security posture is enforced by code, not by process — Checkov violations are caught before `apply`
- Observability dashboards ship with infrastructure, not weeks later

### Negative / Trade-offs

- Module updates must be applied to both providers in parallel — a small ongoing maintenance cost
- The abstraction level is higher than raw cloud console/SDK — new engineers need Terraform fluency
- Checkov hard-fail on CI can slow velocity if new checks are added upstream; requires periodic skip-list review

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Provider API drift breaking modules | Low | Medium | Provider version pins (`>= 5.0, < 6.0`); Dependabot for provider bumps |
| Checkov false positives blocking releases | Medium | Low | Skip list with documented justification; `soft-fail-on` LOW/MEDIUM |
| State file corruption in shared backend | Low | High | Versioning enabled on S3/GCS backend bucket; DynamoDB state lock |
| Credential leakage in CI | Low | Critical | OIDC/Workload Identity Federation — no static credentials in GitHub Secrets |

---

## References

- [Terraform Module Composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
- [Checkov Documentation](https://www.checkov.io/)
- [Google Cloud VPC best practices](https://cloud.google.com/vpc/docs/best-practices)
- [AWS VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [HIPAA Security Rule §164.312(b)](https://www.hhs.gov/hipaa/for-professionals/security/laws-regulations/index.html)
