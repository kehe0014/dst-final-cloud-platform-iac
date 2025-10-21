provide a github action file for this make file. The terraform apply should be a manual step:
# Makefile for Terraform EKS Deployment
# Simulates Jenkins pipeline stages locally

# Configuration
AWS_REGION ?= eu-west-3
TF_VERSION ?= 1.5.0
KUBE_VERSION ?= 1.28
TF_IN_AUTOMATION = true
TF_INPUT = false

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

# Export environment variables
export AWS_REGION
export TF_IN_AUTOMATION
export TF_INPUT
export TF_VERSION
export KUBE_VERSION

.PHONY: all check-env checkout-setup init plan approval apply destroy clean help

all: check-env checkout-setup init plan

##@ Main Targets

deploy: check-env checkout-setup init plan approval apply ## Full deployment with manual approval

auto-deploy: check-env checkout-setup init plan apply ## Automated deployment without approval

destroy: check-env ## Destroy infrastructure
	@echo -e "$(YELLOW)Destroying infrastructure...$(NC)"
	@read -p "Are you sure you want to destroy all infrastructure? (yes/no): " confirm && [ $$confirm = "yes" ]
	terraform destroy -auto-approve \
		-var="aws_region=$(AWS_REGION)" \
		-var="cluster_version=$(KUBE_VERSION)"

##@ Pipeline Stages

check-env: ## Check environment prerequisites
	@echo -e "$(BLUE)=== Checking Environment ===$(NC)"
	@command -v terraform >/dev/null 2>&1 || { echo -e "$(RED)Error: terraform is not installed$(NC)"; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo -e "$(RED)Error: aws cli is not installed$(NC)"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo -e "$(RED)Error: kubectl is not installed$(NC)"; exit 1; }
	@terraform --version
	@aws --version
	@kubectl version --client
	@if [ -z "$$AWS_ACCESS_KEY_ID" ] || [ -z "$$AWS_SECRET_ACCESS_KEY" ]; then \
		echo -e "$(RED)Error: AWS credentials not set. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)✓ Environment check passed$(NC)"

checkout-setup: ## Checkout & Setup stage
	@echo -e "$(BLUE)=== Checkout & Setup ===$(NC)"
	@echo "Working directory: $(shell pwd)"
	@terraform --version
	@aws --version
	@kubectl version --client
	@echo -e "$(GREEN)✓ Checkout & Setup completed$(NC)"

init: ## Terraform Init stage
	@echo -e "$(BLUE)=== Terraform Init ===$(NC)"
	@if [ -d "modules/vpc" ]; then \
		echo "Initializing VPC module..."; \
		cd modules/vpc && terraform init -backend=false -no-color && cd -; \
	fi
	@if [ -d "modules/eks" ]; then \
		echo "Initializing EKS module..."; \
		cd modules/eks && terraform init -backend=false -no-color && cd -; \
	fi
	@if [ -d "modules/iam" ]; then \
		echo "Initializing IAM module..."; \
		cd modules/iam && terraform init -backend=false -no-color && cd -; \
	fi
	@echo "Initializing root module..."
	@terraform init -backend=false -no-color
	@echo -e "$(GREEN)✓ Terraform Init completed$(NC)"

plan: ## Terraform Plan stage
	@echo -e "$(BLUE)=== Terraform Plan ===$(NC)"
	@terraform plan \
		-var="aws_region=$(AWS_REGION)" \
		-var="cluster_version=$(KUBE_VERSION)" \
		-out=tfplan \
		-no-color
	@echo -e "$(GREEN)✓ Terraform Plan completed$(NC)"
	@echo -e "$(YELLOW)Plan saved to 'tfplan'$(NC)"

approval: ## Manual Approval stage
	@echo -e "$(BLUE)=== Manual Approval ===$(NC)"
	@echo -e "$(YELLOW)Waiting for approval to apply changes...$(NC)"
	@echo -e "$(YELLOW)Type 'Deploy' to approve or Ctrl+C to cancel$(NC)"
	@read -p "Approve Terraform Apply? " confirm && [ "$$confirm" = "Deploy" ]
	@echo -e "$(GREEN)✓ Approval granted$(NC)"

apply: ## Terraform Apply stage
	@echo -e "$(BLUE)=== Terraform Apply ===$(NC)"
	@if [ ! -f "tfplan" ]; then \
		echo -e "$(RED)Error: tfplan file not found. Run 'make plan' first.$(NC)"; \
		exit 1; \
	fi
	@terraform apply -auto-approve -no-color tfplan
	@echo -e "$(GREEN)✓ Terraform Apply completed$(NC)"

##@ Utility Targets

validate: init ## Validate Terraform configuration
	@echo -e "$(BLUE)=== Validating Terraform ===$(NC)"
	@terraform validate
	@echo -e "$(GREEN)✓ Validation completed$(NC)"

fmt: ## Format Terraform code
	@echo -e "$(BLUE)=== Formatting Terraform Code ===$(NC)"
	@terraform fmt -recursive
	@echo -e "$(GREEN)✓ Formatting completed$(NC)"

clean: ## Clean up generated files
	@echo -e "$(BLUE)=== Cleaning Up ===$(NC)"
	@rm -f tfplan
	@rm -rf .terraform
	@find . -name "*.terraform*" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo -e "$(GREEN)✓ Cleanup completed$(NC)"

post-success: ## Post-build success actions
	@echo -e "$(GREEN)=== DEPLOYMENT SUCCESSFUL ===$(NC)"
	@echo "EKS Deployment Successful"

post-failure: ## Post-build failure actions
	@echo -e "$(RED)=== DEPLOYMENT FAILED ===$(NC)"
	@echo "EKS Deployment Failed"

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# Set default target
.DEFAULT_GOAL := help