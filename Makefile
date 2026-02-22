.PHONY: help init plan apply destroy fmt validate lint clean status

MODULES_DIR ?= ./modules
VALUES_FILE ?= values/docker-desktop.yaml
ENV_FILE ?= .env

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	terraform -chdir=$(MODULES_DIR) init

plan: _load-env ## Plan infrastructure changes
	terraform -chdir=$(MODULES_DIR) plan -var="values_path=$(VALUES_FILE)"

apply: _load-env ## Apply infrastructure changes
	terraform -chdir=$(MODULES_DIR) apply -var="values_path=$(VALUES_FILE)" -auto-approve

destroy: _load-env ## Destroy all infrastructure
	terraform -chdir=$(MODULES_DIR) destroy -var="values_path=$(VALUES_FILE)" -auto-approve

fmt: ## Format Terraform files
	terraform fmt -recursive $(MODULES_DIR)

validate: init ## Validate Terraform configuration
	terraform -chdir=$(MODULES_DIR) validate

lint: ## Run TFLint
	cd $(MODULES_DIR) && tflint --init && tflint

clean: ## Clean Terraform cache and lock files
	rm -rf $(MODULES_DIR)/.terraform
	rm -f $(MODULES_DIR)/.terraform.lock.hcl

status: ## Show current Terraform state
	terraform -chdir=$(MODULES_DIR) show

output: ## Show Terraform outputs
	terraform -chdir=$(MODULES_DIR) output

# Environment targets
dev: ## Deploy to dev (docker-desktop)
	$(MAKE) apply VALUES_FILE=values/docker-desktop.yaml

staging: ## Deploy to staging
	$(MAKE) apply VALUES_FILE=values/staging.yaml

production: ## Deploy to production (requires confirmation)
	@echo "⚠️  You are about to deploy to PRODUCTION."
	@read -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	$(MAKE) apply VALUES_FILE=values/production.yaml

dev-destroy: ## Destroy dev environment
	$(MAKE) destroy VALUES_FILE=values/docker-desktop.yaml

staging-destroy: ## Destroy staging environment
	$(MAKE) destroy VALUES_FILE=values/staging.yaml

production-destroy: ## Destroy production (requires confirmation)
	@echo "⚠️  You are about to DESTROY PRODUCTION."
	@read -p "Type 'yes-destroy-production' to continue: " confirm && [ "$$confirm" = "yes-destroy-production" ] || exit 1
	$(MAKE) destroy VALUES_FILE=values/production.yaml

# Internal targets
_load-env:
	@if [ -f "$(ENV_FILE)" ]; then \
		echo "Loading environment from $(ENV_FILE)"; \
		set -a && . ./$(ENV_FILE) && set +a; \
	fi
