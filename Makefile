# Enterprise GitOps Platform - Developer Task Runner
SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help
help: ## Display this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: fmt
fmt: ## Format Terraform and repository files
	@echo "==> Formatting Terraform configurations..."
	terraform -chdir=terraform fmt -recursive

.PHONY: lint
lint: ## Run format checks and Helm linting
	@echo "==> Checking Terraform formatting..."
	terraform -chdir=terraform fmt -check
	@echo "==> Validating Helm chart templates..."
	helm lint gitops/infrastructure

.PHONY: tf-init
tf-init: ## Initialize Terraform providers and backend
	@echo "==> Initializing Terraform..."
	terraform -chdir=terraform init

.PHONY: tf-validate
tf-validate: tf-init ## Validate Terraform code
	@echo "==> Validating Terraform syntax and references..."
	terraform -chdir=terraform validate

.PHONY: tf-plan
tf-plan: tf-init ## Run Terraform execution plan
	@echo "==> Generating Terraform plan..."
	terraform -chdir=terraform plan -var-file=terraform.tfvars.example

.PHONY: test
test: tf-validate lint ## Run all local CI tests (Terraform validation, format, Helm lint)
	@echo "==> All validation checks passed successfully!"

.PHONY: clean
clean: ## Clean local cache, state backups, and temp files
	@echo "==> Cleaning cache files..."
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/terraform.tfstate.backup
