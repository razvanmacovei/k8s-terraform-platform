.PHONY: help init list plan apply destroy fmt validate lint clean status output

MODULES_DIR ?= ./modules
ENV_FILE ?= .env

ifdef ENV
VALUES_FILE = values/$(ENV).yaml
endif

define check_env
@if [ -z "$(ENV)" ]; then \
	echo "Error: ENV is required."; \
	echo ""; \
	echo "Usage: make <command> ENV=<environment>"; \
	echo ""; \
	echo "Available environments (make list):"; \
	for f in values/*.yaml; do \
		name=$$(basename "$$f" .yaml); \
		echo "  $$name"; \
	done; \
	echo ""; \
	echo "Example: make plan ENV=docker-desktop"; \
	exit 1; \
fi
@if [ ! -f "$(VALUES_FILE)" ]; then \
	echo "Error: Values file '$(VALUES_FILE)' not found"; \
	exit 1; \
fi
endef

define load_env
@if [ -f "$(ENV_FILE)" ]; then \
	echo "Loading environment from $(ENV_FILE)"; \
	set -a && . ./$(ENV_FILE) && set +a; \
fi
endef

# Extract kube config from values YAML and export as env vars for the kubernetes backend
define set_kube_env
export KUBE_CONFIG_PATH=$$(grep 'kubeconfig_path' $(VALUES_FILE) | head -1 | awk '{print $$2}' | tr -d '"') && \
export KUBE_CTX=$$(grep 'kube_context' $(VALUES_FILE) | head -1 | awk '{print $$2}' | tr -d '"')
endef

define select_workspace
@$(set_kube_env) && \
(terraform -chdir=$(MODULES_DIR) workspace select $(ENV) 2>/dev/null || \
	terraform -chdir=$(MODULES_DIR) workspace new $(ENV))
endef

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform (requires ENV)
	$(check_env)
	@echo "Ensuring terraform-state namespace exists..."
	@kubectl --context $$(grep 'kube_context' $(VALUES_FILE) | head -1 | awk '{print $$2}' | tr -d '"') \
		create namespace terraform-state 2>/dev/null || true
	@$(set_kube_env) && terraform -chdir=$(MODULES_DIR) init

list: ## List available environments
	@echo "Available environments:"
	@for f in values/*.yaml; do \
		name=$$(basename "$$f" .yaml); \
		echo "  $$name"; \
	done

plan: ## Plan changes (requires ENV)
	$(check_env)
	$(load_env)
	$(select_workspace)
	@$(set_kube_env) && terraform -chdir=$(MODULES_DIR) plan -var="values_path=$(VALUES_FILE)"

apply: ## Apply changes (requires ENV)
	$(check_env)
	$(load_env)
	$(select_workspace)
	@if [ "$(ENV)" = "production" ]; then \
		echo "WARNING: You are about to deploy to PRODUCTION."; \
		read -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1; \
	fi
	@$(set_kube_env) && terraform -chdir=$(MODULES_DIR) apply -var="values_path=$(VALUES_FILE)" -auto-approve

destroy: ## Destroy infrastructure (requires ENV)
	$(check_env)
	$(load_env)
	$(select_workspace)
	@if [ "$(ENV)" = "production" ]; then \
		echo "WARNING: You are about to DESTROY PRODUCTION."; \
		read -p "Type 'yes-destroy-production' to continue: " confirm && [ "$$confirm" = "yes-destroy-production" ] || exit 1; \
	fi
	@$(set_kube_env) && terraform -chdir=$(MODULES_DIR) destroy -var="values_path=$(VALUES_FILE)" -auto-approve

fmt: ## Format Terraform files
	terraform fmt -recursive $(MODULES_DIR)

validate: ## Validate Terraform configuration (requires ENV)
	$(check_env)
	@$(set_kube_env) && terraform -chdir=$(MODULES_DIR) validate

lint: ## Run TFLint
	cd $(MODULES_DIR) && tflint --init && tflint

clean: ## Clean Terraform cache and lock files
	rm -rf $(MODULES_DIR)/.terraform
	rm -f $(MODULES_DIR)/.terraform.lock.hcl

status: ## Show current Terraform state (requires ENV)
	$(check_env)
	$(select_workspace)
	@$(set_kube_env) && terraform -chdir=$(MODULES_DIR) show

output: ## Show Terraform outputs (requires ENV)
	$(check_env)
	$(select_workspace)
	@$(set_kube_env) && terraform -chdir=$(MODULES_DIR) output
