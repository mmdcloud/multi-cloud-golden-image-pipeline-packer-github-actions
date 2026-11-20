# ==============================================================================
# Multi-Cloud Golden Image Pipeline Makefile
# ==============================================================================

SHELL := /bin/bash
PACKER_DIR := packer
VARS_DIR := $(PACKER_DIR)/vars

.PHONY: help init fmt validate lint test build-aws build-gcp build-azure clean checkov

help: ## Display this help screen
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Packer plugins
	@echo "==> Initializing Packer plugins..."
	packer init $(PACKER_DIR)/versions.pkr.hcl

fmt: ## Format Packer HCL code
	@echo "==> Formatting Packer HCL files..."
	packer fmt -recursive $(PACKER_DIR)

validate: init ## Validate all Packer templates against providers
	@echo "==> Validating AWS configuration..."
	packer validate -var-file="$(VARS_DIR)/common.pkrvars.hcl" -var-file="$(VARS_DIR)/aws.pkrvars.hcl" -only="amazon-ebs.builder" $(PACKER_DIR)
	@echo "==> Validating GCP configuration..."
	packer validate -var-file="$(VARS_DIR)/common.pkrvars.hcl" -var-file="$(VARS_DIR)/gcp.pkrvars.hcl" -only="googlecompute.builder" $(PACKER_DIR)
	@echo "==> Validating Azure configuration..."
	packer validate -var-file="$(VARS_DIR)/common.pkrvars.hcl" -var-file="$(VARS_DIR)/azure.pkrvars.hcl" -only="azure-arm.builder" $(PACKER_DIR)
	@echo "==> All configurations valid."

lint: fmt ## Run linting checks (checkov, shellcheck, ansible-lint)
	@echo "==> Running shellcheck..."
	@which shellcheck >/dev/null 2>&1 && shellcheck scripts/*.sh || echo "shellcheck not found; skipping"
	@echo "==> Running Ansible syntax check..."
	ansible-playbook --syntax-check -i ansible/ansible.cfg ansible/playbook.yml

checkov: ## Run Checkov security scanner
	@echo "==> Running Checkov security scan..."
	checkov -d $(PACKER_DIR) --framework all

build-aws: init ## Build AWS Golden AMI locally
	packer build \
		-var-file="$(VARS_DIR)/common.pkrvars.hcl" \
		-var-file="$(VARS_DIR)/aws.pkrvars.hcl" \
		-only="amazon-ebs.builder" \
		$(PACKER_DIR)

build-gcp: init ## Build GCP Golden Compute Image locally
	packer build \
		-var-file="$(VARS_DIR)/common.pkrvars.hcl" \
		-var-file="$(VARS_DIR)/gcp.pkrvars.hcl" \
		-only="googlecompute.builder" \
		$(PACKER_DIR)

build-azure: init ## Build Azure Golden Managed Image locally
	packer build \
		-var-file="$(VARS_DIR)/common.pkrvars.hcl" \
		-var-file="$(VARS_DIR)/azure.pkrvars.hcl" \
		-only="azure-arm.builder" \
		$(PACKER_DIR)

clean: ## Clean up local manifest files and test artifacts
	@echo "==> Cleaning local build artifacts..."
	rm -f manifest-*.json
	rm -rf .packer.d/
