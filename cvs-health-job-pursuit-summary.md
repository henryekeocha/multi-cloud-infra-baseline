# CVS Health — Principal Engineer (Cloud Infrastructure) Job Pursuit
**Session Date:** April 6, 2026  
**Role:** Principal Engineer – Cloud Infrastructure  
**Job ID:** R0694233  
**Closing Date:** April 17, 2026  
**Status:** Applied ✅ | Recruiter outreach drafted ✅ | Repo build in progress 🔄

---

## 1. Role Overview

- **Company:** CVS Health
- **Location:** Remote (Rhode Island base)
- **Pay Range:** $144,200 – $288,400 + bonus + equity
- **Team:** Innovation & Technology / Data & Analytics
- **Link:** https://jobs.cvshealth.com/us/en/job/R0694233/Principal-Engineer-Cloud-Infrastructure *(posting now closed/filled)*

### Core JD Requirements
- 10+ years experience
- Deep knowledge of **at least 2 cloud platforms** (GCP, AWS, Azure)
- IaC (Terraform), orchestration, automation
- Security controls: IAM, encryption, vulnerability scanning
- Observability: monitoring, bottleneck identification, performance analysis
- POC evaluation of new cloud services
- Cross-functional collaboration + mentoring junior engineers

---

## 2. Recruiters Identified

| Name | Title | Priority |
|---|---|---|
| **Danielle Szestakow** | Senior Talent Acquisition Partner, Enterprise IT | 🥇 First contact |
| **Derek Tucker** | Tech Recruiter (AI/ML, **Infra**, GRC, IAM) | 🥈 Second contact |
| **Shelly Jones** | Senior Technical Recruiter (Software Dev focus) | Hold for now |

### Outreach Strategy
- Henry has already applied — messages are positioned as **follow-up, not cold outreach**
- Job ID R0694233 included in both messages for easy lookup
- GitHub repo + portfolio linked as proof of expertise
- Message to Danielle: senior scope, cross-functional leadership angle
- Message to Derek: infra domain match, direct and confident tone

---

## 3. Recruiter Messages (Drafted)

### Danielle Szestakow
> Hi Danielle, I recently applied for the Principal Engineer – Cloud Infrastructure role (R0694233) at CVS Health and wanted to reach out directly. I'm a Cloud & DevOps Engineer with hands-on experience designing and operating Kubernetes-based infrastructure at scale, building internal developer platforms, and integrating AI/ML workloads into cloud-native environments. I've led infrastructure work across AWS and GCP, and I'm currently publishing benchmarking research on LLM inference stacks on Kubernetes — work that sits exactly at the intersection of cloud infrastructure and modern AI. Beyond the technical depth, I bring a track record of driving platform adoption and working cross-functionally with engineering teams — which I understand is a big part of what a Principal Engineer role demands at an org like CVS Health.
> 
> 🔗 GitHub: github.com/henryekeocha (llm-k8s-benchmark repo)  
> 🔗 Portfolio: henryekeocha.com
> 
> I'd love the chance to connect and learn more about what the team is looking for. Would you be open to a brief conversation?
> Henry Ekeocha

### Derek Tucker
> Hi Derek, I came across your profile while researching the CVS Health tech recruiting team and noticed you cover Infrastructure — which is exactly why I wanted to reach out. I recently applied for the Principal Engineer – Cloud Infrastructure role (R0694233) and wanted to make sure my application is on your radar. I specialize in Kubernetes, cloud-native platform engineering, and AI/ML infrastructure — specifically the kind of foundational work that keeps large-scale engineering orgs moving fast. I've built and operated internal developer platforms, designed multi-cloud infrastructure on AWS and GCP, and I'm currently conducting and publishing research benchmarking LLM inference performance on Kubernetes clusters.
>
> 🔗 GitHub: github.com/henryekeocha (see: llm-k8s-benchmark)  
> 🔗 Portfolio: henryekeocha.com
>
> Would love 15 minutes to connect if you're the right person, or happy to be pointed in the right direction.
> Henry Ekeocha

---

## 4. Portfolio / Proof of Work Strategy

### What to link in outreach
- **GitHub:** github.com/henryekeocha
- **Portfolio:** henryekeocha.com
- **New repo (in progress):** `multi-cloud-infra-baseline`

### Existing Terraform Repo (foundation)
- **Repo:** `aws-terraform-multi-env-infra`
- **What it has:** Modular AWS VPC, multi-env (dev/prod), remote state (S3 + DynamoDB), GitHub Actions CI, pre-commit hooks, TFLint, VPC Flow Logs
- **Gap vs JD:** AWS only, no GCP, no security scanning, no observability layer, no POC writeup

---

## 5. New Repo to Build: `multi-cloud-infra-baseline`

### Decision
Create a **new repo** (don't rename existing one). Reasons:
- Clean git history with intentional commit messages
- New narrative: multi-cloud POC vs AWS-only networking
- Existing repo stays live as a second proof point

### What to Build (4-Hour Plan)

#### Hour 1 — GCP Terraform Module
- Add `modules/gcp/vpc/` with GCP VPC, subnets, firewall rules
- Mirror the AWS module structure
- Hits: *"deep knowledge of at least 2 cloud platforms"*

#### Hour 2 — Security Baseline
- Add Checkov to GitHub Actions CI pipeline
- Add `security/` folder with Checkov config
- Hits: *"implements security controls, vulnerability scanning"*

#### Hour 3 — Observability Layer
- Add `monitoring/` folder
- `docker-compose.yml` with Prometheus + Grafana
- Pre-built Grafana dashboard JSON for cloud infra metrics
- Hits: *"monitoring and analyzing performance of cloud infrastructure"*

#### Hour 4 — POC README (Most Important)
Rewrite README as a **Principal Engineer POC document** including:
- Problem statement
- Architecture Decision Records (ADRs)
- Security posture summary
- Observability strategy
- Production rollout plan

### Target Folder Structure
```
multi-cloud-infra-baseline/
├── modules/
│   ├── aws/vpc/
│   └── gcp/vpc/
├── envs/
│   ├── dev/
│   └── prod/
├── global/backend-bootstrap/
├── security/
│   └── checkov-config.yaml
├── monitoring/
│   ├── docker-compose.yml
│   └── dashboards/infra-overview.json
├── .github/workflows/
│   ├── terraform-ci.yml
│   └── security-scan.yml
├── docs/
│   └── adr-001-multi-cloud-strategy.md
├── Makefile
└── README.md  ← POC writeup
```

---

## 6. Next Steps (In Order)

- [ ] Send LinkedIn message to **Danielle Szestakow**
- [ ] Send LinkedIn message to **Derek Tucker**
- [ ] Create new GitHub repo: `multi-cloud-infra-baseline`
- [ ] Copy AWS Terraform code from existing repo into new repo
- [ ] **Hour 1:** Build GCP VPC Terraform module
- [ ] **Hour 2:** Add Checkov security scanning to CI
- [ ] **Hour 3:** Add Prometheus + Grafana monitoring folder
- [ ] **Hour 4:** Write POC README
- [ ] Update recruiter messages with new repo link once live
- [ ] Ensure `henryekeocha.com` links to new repo

---

## 7. Cowork Instructions (For Next Session)

When you open this file in Cowork, point Claude at the `multi-cloud-infra-baseline` repo folder and say:

> "I'm building a multi-cloud infrastructure baseline repo to demonstrate Principal Engineer-level cloud skills for a CVS Health job application. The plan is in the summary doc. Start with Hour 1: build the GCP VPC Terraform module inside `modules/gcp/vpc/` mirroring the existing AWS module structure. Then proceed through Hours 2–4 as outlined."

---

*Summary generated from Claude chat session on April 6, 2026*
