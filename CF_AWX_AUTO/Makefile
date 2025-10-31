# AWX Cloudflare Automation - Distribution Makefile
# This Makefile automates the building, tagging, and pushing of the patched AWX image
# and the setup/configuration of AWX for Cloudflare automation

# ==============================================================================
# Configuration Variables
# ==============================================================================

# Docker/Registry Configuration
REGISTRY ?= docker.io
REGISTRY_USER ?= blackthami
IMAGE_NAME ?= awx-cloudflare-auto
AWX_VERSION ?= 24.6.1
IMAGE_TAG ?= $(AWX_VERSION)-cf-auto
FULL_IMAGE := $(REGISTRY)/$(REGISTRY_USER)/$(IMAGE_NAME):$(IMAGE_TAG)

# Kubernetes Configuration  
KUBE_NAMESPACE ?= awx
AWX_INSTANCE_NAME ?= ansible-awx
AWX_ADMIN_USER ?= admin

# AWX Template Configuration
AWX_TEMPLATE_ID ?= 21
AWX_TEMPLATE_NAME ?= "Cloudflare - Automation"
AWX_HOST ?= localhost:8052

# Cloudflare Configuration
CLOUDFLARE_API_TOKEN ?=

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

# ==============================================================================
# Help Target
# ==============================================================================

.PHONY: help
help: ## Show this help message
	@echo '$(BLUE)AWX Cloudflare Automation - Available Commands$(RESET)'
	@echo ''
	@echo '$(YELLOW)Image Building & Registry:$(RESET)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; /build-image|push-image|tag-image|login-registry/ {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ''
	@echo '$(YELLOW)AWX Installation & Setup:$(RESET)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; /install-operator|deploy-awx|create-secret|get-password/ {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ''
	@echo '$(YELLOW)AWX Configuration:$(RESET)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; /configure-template|apply-survey|update-dropdowns|verify-survey/ {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ''
	@echo '$(YELLOW)Utilities:$(RESET)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; /port-forward|check-awx|clean/ {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ''
	@echo '$(YELLOW)Examples:$(RESET)'
	@echo '  make build-image REGISTRY_USER=myuser IMAGE_TAG=latest'
	@echo '  make push-image'
	@echo '  make install-all CLOUDFLARE_API_TOKEN=your_token'

# ==============================================================================
# Image Building & Registry Targets
# ==============================================================================

.PHONY: build-image
build-image: ## Build the patched AWX image
	@echo "$(BLUE)Building AWX patched image...$(RESET)"
	@echo "  Image: $(FULL_IMAGE)"
	@cd awx-image && docker build \
		--build-arg AWX_VERSION=$(AWX_VERSION) \
		-t $(FULL_IMAGE) \
		-t $(REGISTRY)/$(REGISTRY_USER)/$(IMAGE_NAME):latest \
		.
	@echo "$(GREEN)✅ Image built successfully: $(FULL_IMAGE)$(RESET)"

.PHONY: tag-image
tag-image: ## Tag image with custom tag (use TAG=your-tag)
	@if [ -z "$(TAG)" ]; then \
		echo "$(RED)❌ Error: TAG variable is required$(RESET)"; \
		echo "  Usage: make tag-image TAG=your-custom-tag"; \
		exit 1; \
	fi
	@echo "$(BLUE)Tagging image...$(RESET)"
	@docker tag $(FULL_IMAGE) $(REGISTRY)/$(REGISTRY_USER)/$(IMAGE_NAME):$(TAG)
	@echo "$(GREEN)✅ Tagged: $(REGISTRY)/$(REGISTRY_USER)/$(IMAGE_NAME):$(TAG)$(RESET)"

.PHONY: login-registry
login-registry: ## Login to container registry
	@echo "$(BLUE)Logging into registry $(REGISTRY)...$(RESET)"
	@docker login $(REGISTRY)
	@echo "$(GREEN)✅ Logged in successfully$(RESET)"

.PHONY: push-image
push-image: ## Push image to registry
	@echo "$(BLUE)Pushing image to registry...$(RESET)"
	@echo "  Pushing: $(FULL_IMAGE)"
	@docker push $(FULL_IMAGE)
	@echo "  Pushing: $(REGISTRY)/$(REGISTRY_USER)/$(IMAGE_NAME):latest"
	@docker push $(REGISTRY)/$(REGISTRY_USER)/$(IMAGE_NAME):latest
	@echo "$(GREEN)✅ Image pushed successfully$(RESET)"

.PHONY: build-and-push
build-and-push: build-image push-image ## Build and push image in one command

# ==============================================================================
# AWX Installation Targets
# ==============================================================================

.PHONY: install-operator
install-operator: ## Install AWX Operator in cluster
	@echo "$(BLUE)Installing AWX Operator...$(RESET)"
	@kubectl create namespace $(KUBE_NAMESPACE) || true
	@kubectl apply -k https://github.com/ansible/awx-operator/config/default?ref=2.19.1
	@echo "$(GREEN)✅ AWX Operator installed$(RESET)"
	@echo "$(YELLOW)⏳ Waiting for operator to be ready...$(RESET)"
	@kubectl wait --for=condition=available --timeout=300s \
		deployment/awx-operator-controller-manager -n awx-system || true

.PHONY: create-secret
create-secret: ## Create Cloudflare credentials secret
	@if [ -z "$(CLOUDFLARE_API_TOKEN)" ]; then \
		echo "$(RED)❌ Error: CLOUDFLARE_API_TOKEN is required$(RESET)"; \
		echo "  Usage: make create-secret CLOUDFLARE_API_TOKEN=your_token"; \
		exit 1; \
	fi
	@echo "$(BLUE)Creating Cloudflare credentials secret...$(RESET)"
	@kubectl create secret generic cloudflare-credentials \
		--from-literal=token=$(CLOUDFLARE_API_TOKEN) \
		-n $(KUBE_NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "$(GREEN)✅ Secret created$(RESET)"

.PHONY: deploy-awx
deploy-awx: ## Deploy AWX instance (requires awx-instance.yaml in config/)
	@echo "$(BLUE)Deploying AWX instance...$(RESET)"
	@if [ ! -f config/awx-instance.yaml ]; then \
		echo "$(RED)❌ Error: config/awx-instance.yaml not found$(RESET)"; \
		echo "  Please create AWX instance configuration file"; \
		exit 1; \
	fi
	@kubectl apply -f config/awx-instance.yaml -n $(KUBE_NAMESPACE)
	@echo "$(GREEN)✅ AWX deployment initiated$(RESET)"
	@echo "$(YELLOW)⏳ Waiting for AWX to be ready (this may take several minutes)...$(RESET)"
	@kubectl wait --for=condition=Progressing=False \
		awx/$(AWX_INSTANCE_NAME) -n $(KUBE_NAMESPACE) --timeout=600s || true

.PHONY: get-password
get-password: ## Get AWX admin password
	@echo "$(BLUE)AWX Admin Password:$(RESET)"
	@kubectl get secret $(AWX_INSTANCE_NAME)-admin-password \
		-n $(KUBE_NAMESPACE) \
		-o jsonpath="{.data.password}" | base64 --decode && echo

# ==============================================================================
# AWX Configuration Targets
# ==============================================================================

.PHONY: port-forward
port-forward: ## Start port-forward to access AWX UI
	@echo "$(BLUE)Starting port-forward to AWX...$(RESET)"
	@echo "$(GREEN)✅ AWX will be available at: http://localhost:8052$(RESET)"
	@echo "$(YELLOW)Press Ctrl+C to stop$(RESET)"
	@kubectl port-forward -n $(KUBE_NAMESPACE) svc/$(AWX_INSTANCE_NAME)-service 8052:80

.PHONY: configure-template
configure-template: ## Update AWX template name and description
	@echo "$(BLUE)Configuring AWX template...$(RESET)"
	@./scripts/awx_survey_manager.sh update-template \
		--template-id $(AWX_TEMPLATE_ID) \
		--host $(AWX_HOST)
	@echo "$(GREEN)✅ Template configured$(RESET)"

.PHONY: apply-survey
apply-survey: ## Apply survey configuration to AWX template
	@echo "$(BLUE)Applying survey configuration...$(RESET)"
	@./scripts/awx_survey_manager.sh apply-survey \
		--template-id $(AWX_TEMPLATE_ID) \
		--host $(AWX_HOST)
	@echo "$(GREEN)✅ Survey applied$(RESET)"

.PHONY: update-dropdowns
update-dropdowns: ## Update survey dropdowns with live Cloudflare data
	@if [ -z "$(CLOUDFLARE_API_TOKEN)" ]; then \
		echo "$(RED)❌ Error: CLOUDFLARE_API_TOKEN is required$(RESET)"; \
		echo "  Usage: make update-dropdowns CLOUDFLARE_API_TOKEN=your_token"; \
		exit 1; \
	fi
	@echo "$(BLUE)Updating survey dropdowns with Cloudflare data...$(RESET)"
	@CLOUDFLARE_API_TOKEN=$(CLOUDFLARE_API_TOKEN) \
		./scripts/awx_survey_manager.sh update-dropdowns \
		--template-id $(AWX_TEMPLATE_ID) \
		--host $(AWX_HOST)
	@echo "$(GREEN)✅ Dropdowns updated$(RESET)"

.PHONY: verify-survey
verify-survey: ## Verify survey configuration
	@echo "$(BLUE)Verifying survey configuration...$(RESET)"
	@./scripts/awx_survey_manager.sh verify-changes \
		--template-id $(AWX_TEMPLATE_ID) \
		--host $(AWX_HOST)

# ==============================================================================
# Utility Targets
# ==============================================================================

.PHONY: check-awx
check-awx: ## Check AWX installation status
	@echo "$(BLUE)Checking AWX status...$(RESET)"
	@echo ""
	@echo "$(YELLOW)Operator Status:$(RESET)"
	@kubectl get deployment awx-operator-controller-manager -n awx-system || \
		echo "$(RED)❌ Operator not installed$(RESET)"
	@echo ""
	@echo "$(YELLOW)AWX Instance:$(RESET)"
	@kubectl get awx -n $(KUBE_NAMESPACE) || \
		echo "$(RED)❌ No AWX instance found$(RESET)"
	@echo ""
	@echo "$(YELLOW)AWX Pods:$(RESET)"
	@kubectl get pods -n $(KUBE_NAMESPACE) || \
		echo "$(RED)❌ No pods found$(RESET)"

.PHONY: clean
clean: ## Clean up local Docker images
	@echo "$(BLUE)Cleaning up local images...$(RESET)"
	@docker rmi $(FULL_IMAGE) || true
	@docker rmi $(REGISTRY)/$(REGISTRY_USER)/$(IMAGE_NAME):latest || true
	@echo "$(GREEN)✅ Cleanup complete$(RESET)"

# ==============================================================================
# Complete Installation Target
# ==============================================================================

.PHONY: install-all
install-all: ## Complete installation: operator + AWX + configuration
	@echo "$(BLUE)═══════════════════════════════════════════════════$(RESET)"
	@echo "$(BLUE)  AWX Cloudflare Automation - Complete Installation$(RESET)"
	@echo "$(BLUE)═══════════════════════════════════════════════════$(RESET)"
	@echo ""
	@$(MAKE) install-operator
	@echo ""
	@if [ -n "$(CLOUDFLARE_API_TOKEN)" ]; then \
		$(MAKE) create-secret; \
	else \
		echo "$(YELLOW)⚠️  Skipping secret creation (CLOUDFLARE_API_TOKEN not provided)$(RESET)"; \
	fi
	@echo ""
	@$(MAKE) deploy-awx
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)  ✅ Installation complete!$(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(RESET)"
	@echo "  1. Get admin password: make get-password"
	@echo "  2. Port-forward AWX:    make port-forward"
	@echo "  3. Configure template:  make configure-template"
	@echo "  4. Apply survey:        make apply-survey"
	@echo "  5. Update dropdowns:    make update-dropdowns CLOUDFLARE_API_TOKEN=your_token"

.DEFAULT_GOAL := help
