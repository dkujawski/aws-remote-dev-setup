SHELL := /bin/bash

TERRAFORM_DIR := iac/terraform
TF_VARS_FILE ?= $(TERRAFORM_DIR)/terraform.tfvars

REQUIRED_BINS := terraform aws

.PHONY: all help check-deps install-deps fmt init validate plan apply destroy output deploy ensure-tfvars

all: help

help:
	@echo "Infrastructure orchestration commands"
	@echo
	@echo "Available targets:"
	@echo "  make check-deps         Ensure required CLI tools are installed"
	@echo "  make install-deps       Attempt to install missing CLI tools"
	@echo "  make fmt                Format Terraform configuration"
	@echo "  make init               Initialize the Terraform working directory"
	@echo "  make validate           Validate Terraform configuration"
	@echo "  make plan               Generate an execution plan"
	@echo "  make apply              Apply the Terraform configuration"
	@echo "  make destroy            Destroy Terraform-managed infrastructure"
	@echo "  make output             Show Terraform outputs"
	@echo "  make deploy             Run init, plan, and apply sequentially"
	@echo
	@echo "Optional variables:"
	@echo "  TF_VARS_FILE            Path to terraform.tfvars file (default: $(TF_VARS_FILE))"
	@echo "  TF_PLAN_FLAGS           Additional flags passed to 'terraform plan'"
	@echo "  TF_APPLY_FLAGS          Additional flags passed to 'terraform apply'"
	@echo "  TF_DESTROY_FLAGS        Additional flags passed to 'terraform destroy'"

check-deps:
	@missing=0; \
	for bin in $(REQUIRED_BINS); do \
		if ! command -v $$bin >/dev/null 2>&1; then \
			echo "Missing required tool: $$bin"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo "Run 'make install-deps' to attempt automatic installation."; \
		exit 1; \
	else \
		echo "All required tools are available."; \
	fi

install-deps:
	@missing=(); \
	for bin in $(REQUIRED_BINS); do \
		if ! command -v $$bin >/dev/null 2>&1; then \
			missing+=($$bin); \
		fi; \
	done; \
	if [ $${#missing[@]} -eq 0 ]; then \
		echo "All required tools are already installed."; \
		exit 0; \
	fi; \
	if command -v apt-get >/dev/null 2>&1; then \
		packages=(); \
		for bin in $${missing[@]}; do \
			case $$bin in \
				aws) packages+=(awscli) ;; \
				*) packages+=($$bin) ;; \
			esac; \
		done; \
		echo "Installing missing tools with apt-get: $${packages[*]}"; \
		if command -v sudo >/dev/null 2>&1; then \
			SUDO=sudo; \
		else \
			SUDO=""; \
		fi; \
		$${SUDO} apt-get update && $${SUDO} apt-get install -y $${packages[*]}; \
	elif command -v brew >/dev/null 2>&1; then \
		packages=(); \
		for bin in $${missing[@]}; do \
			case $$bin in \
				aws) packages+=(awscli) ;; \
				*) packages+=($$bin) ;; \
			esac; \
		done; \
		echo "Installing missing tools with Homebrew: $${packages[*]}"; \
		brew install $${packages[*]}; \
	else \
		echo "No supported package manager found (apt-get or brew). Install manually: $${missing[*]}"; \
		exit 1; \
	fi

fmt: check-deps
	cd $(TERRAFORM_DIR) && terraform fmt

init: check-deps
	cd $(TERRAFORM_DIR) && terraform init

validate: check-deps
	cd $(TERRAFORM_DIR) && terraform validate

plan: check-deps ensure-tfvars
	cd $(TERRAFORM_DIR) && terraform plan -var-file=$(TF_VARS_FILE) $(TF_PLAN_FLAGS)

apply: check-deps ensure-tfvars
	cd $(TERRAFORM_DIR) && terraform apply -var-file=$(TF_VARS_FILE) $(TF_APPLY_FLAGS)

destroy: check-deps ensure-tfvars
	cd $(TERRAFORM_DIR) && terraform destroy -var-file=$(TF_VARS_FILE) $(TF_DESTROY_FLAGS)

output: check-deps ensure-tfvars
	cd $(TERRAFORM_DIR) && terraform output

deploy: check-deps ensure-tfvars
	cd $(TERRAFORM_DIR) && terraform init && \
		terraform plan -var-file=$(TF_VARS_FILE) $(TF_PLAN_FLAGS) && \
		terraform apply -var-file=$(TF_VARS_FILE) $(TF_APPLY_FLAGS)

ensure-tfvars:
	@if [ ! -f "$(TF_VARS_FILE)" ]; then \
		echo "Terraform variables file not found: $(TF_VARS_FILE)"; \
		echo "Copy $(TERRAFORM_DIR)/terraform.tfvars.example to $(TF_VARS_FILE) and update it for your environment."; \
		exit 1; \
	fi
