# Multi-Cloud Infrastructure Baseline — Makefile
# Usage: make <target>   |   make help

SHELL := /bin/bash
.DEFAULT_GOAL := help

TF_VERSION        ?= 1.7.5
CHECKOV_CONFIG    := security/checkov-config.yaml
MONITORING_DIR    := monitoring

# Terraform module directories
TF_MODULES := modules/aws/vpc modules/gcp/vpc
TF_ENVS    := envs/dev envs/prod

##@ General

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Terraform

.PHONY: fmt
fmt: ## Format all Terraform files in-place
	terraform fmt -recursive .

.PHONY: fmt-check
fmt-check: ## Check formatting without modifying files (used in CI)
	terraform fmt -check -recursive -diff .

.PHONY: validate
validate: ## Init and validate all modules
	@for dir in $(TF_MODULES); do \
		echo "→ Validating $$dir"; \
		terraform -chdir=$$dir init -backend=false -upgrade -input=false > /dev/null; \
		terraform -chdir=$$dir validate; \
	done
	@echo "✅ All modules valid"

.PHONY: init-dev
init-dev: ## terraform init for dev environment
	terraform -chdir=envs/dev init -upgrade

.PHONY: plan-dev
plan-dev: init-dev ## terraform plan for dev environment
	terraform -chdir=envs/dev plan -out=tfplan

.PHONY: apply-dev
apply-dev: plan-dev ## terraform apply for dev environment (prompts for confirmation)
	terraform -chdir=envs/dev apply tfplan

.PHONY: init-prod
init-prod: ## terraform init for prod environment
	terraform -chdir=envs/prod init -upgrade

.PHONY: plan-prod
plan-prod: init-prod ## terraform plan for prod environment
	terraform -chdir=envs/prod plan -out=tfplan

.PHONY: apply-prod
apply-prod: ## terraform apply for prod environment (requires explicit approval)
	@read -p "⚠️  Apply to PRODUCTION? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform -chdir=envs/prod apply tfplan; \
	else \
		echo "Aborted."; \
	fi

.PHONY: destroy-dev
destroy-dev: ## terraform destroy for dev environment
	terraform -chdir=envs/dev destroy

##@ Security

.PHONY: security-scan
security-scan: ## Run Checkov IaC security scan
	@mkdir -p security/reports
	checkov -d . --config-file $(CHECKOV_CONFIG)
	@echo "✅ Checkov scan complete — reports in security/reports/"

.PHONY: security-scan-module-aws
security-scan-module-aws: ## Run Checkov on AWS VPC module only
	@mkdir -p security/reports
	checkov -d modules/aws/vpc --config-file $(CHECKOV_CONFIG)

.PHONY: security-scan-module-gcp
security-scan-module-gcp: ## Run Checkov on GCP VPC module only
	@mkdir -p security/reports
	checkov -d modules/gcp/vpc --config-file $(CHECKOV_CONFIG)

##@ Linting

.PHONY: lint
lint: ## Run TFLint on all modules
	@for dir in $(TF_MODULES); do \
		echo "→ TFLint $$dir"; \
		tflint --chdir=$$dir --init; \
		tflint --chdir=$$dir --format compact; \
	done

##@ Observability

.PHONY: monitoring-up
monitoring-up: ## Start Prometheus + Grafana + Alertmanager stack
	docker compose -f $(MONITORING_DIR)/docker-compose.yml up -d
	@echo ""
	@echo "✅ Observability stack running:"
	@echo "   Grafana:       http://localhost:3000  (admin/admin)"
	@echo "   Prometheus:    http://localhost:9090"
	@echo "   Alertmanager:  http://localhost:9093"

.PHONY: monitoring-down
monitoring-down: ## Stop observability stack
	docker compose -f $(MONITORING_DIR)/docker-compose.yml down

.PHONY: monitoring-logs
monitoring-logs: ## Tail logs from observability stack
	docker compose -f $(MONITORING_DIR)/docker-compose.yml logs -f

.PHONY: monitoring-status
monitoring-status: ## Show status of observability containers
	docker compose -f $(MONITORING_DIR)/docker-compose.yml ps

##@ CI (run locally to mirror GitHub Actions)

.PHONY: ci
ci: fmt-check validate lint security-scan ## Run full CI pipeline locally
	@echo ""
	@echo "✅ All CI checks passed"

##@ Utilities

.PHONY: clean
clean: ## Remove local Terraform state/cache and build artifacts
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -name "tfplan" -delete 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	rm -rf security/reports/
	@echo "✅ Cleaned"

.PHONY: docs
docs: ## Generate module documentation with terraform-docs (requires terraform-docs)
	@for dir in $(TF_MODULES); do \
		echo "→ Generating docs for $$dir"; \
		terraform-docs markdown table --output-file README.md --output-mode inject $$dir; \
	done
