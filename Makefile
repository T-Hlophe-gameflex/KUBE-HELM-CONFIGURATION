# =============================================================================
# 🚀 KUBERNETES INFRASTRUCTURE AUTOMATION MAKEFILE
# =============================================================================
# Purpose: Complete automation for ELK stack and application deployment
# Author: Infrastructure Automation Team
# =============================================================================

.PHONY: help setup-python setup-cluster setup clean deploy-complete deploy-elk deploy-apps remove-complete remove-elk remove-apps cloudflare-dns validate status kibana elasticsearch logs generate-logs install-deps check-env backup restore

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================
KUBESPRAY_DIR := $(HOME)/kubespray
INVENTORY := $(KUBESPRAY_DIR)/inventory/helm-kube-cluster/inventory.ini
ELK_NAMESPACE := elastic-stack
APP_NAMESPACE := app-services
METALLB_NAMESPACE := metallb-system
PYTHON_CMD := /usr/local/bin/python3.13

# Deployment configuration
DEPLOYMENT_MODE ?= complete
EXPOSE_SERVICES ?= true
CLEANUP_FIRST ?= false
STORAGE_CLASS ?= standard
ELASTICSEARCH_MEMORY ?= 2Gi

# Script paths
SCRIPTS_DIR := ./scripts
AUTOMATION_DIR := ./automation

# Color codes for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
NC := \033[0m

# =============================================================================
# HELP AND INFORMATION
# =============================================================================
help:
	@echo -e "$(PURPLE)🚀 Kubernetes Infrastructure Automation Platform$(NC)"
	@echo -e "$(PURPLE)====================================================$(NC)"
	@echo ""
	@echo -e "$(CYAN)📋 SETUP & PREREQUISITES:$(NC)"
	@echo "  setup-python     🐍 Configure Python environment and install packages"
	@echo "  setup-cluster    ⚙️  Create Kind Kubernetes cluster"
	@echo "  setup           ✨ Complete setup (Python + Cluster)"
	@echo "  install-deps    📦 Install system dependencies"
	@echo "  check-env       🔍 Validate environment and prerequisites"
	@echo ""
	@echo -e "$(CYAN)🚀 DEPLOYMENT:$(NC)"
	@echo "  deploy-complete 🎯 Deploy everything (ELK + Apps + MetalLB + AWX)"
	@echo "  deploy-elk      📊 Deploy ELK stack only"
	@echo "  deploy-apps     🚀 Deploy application services only"
	@echo "  deploy-awx      🎭 Deploy AWX with pre-configured templates"
	@echo "  deploy          🔄 Interactive deployment (alias for deploy-complete)"
	@echo ""
	@echo -e "$(CYAN)🧹 CLEANUP:$(NC)"
	@echo "  remove-complete 🗑️  Remove all deployments"
	@echo "  remove-elk      📊 Remove ELK stack only"
	@echo "  remove-apps     🚀 Remove application services only"
	@echo "  clean-cluster   ⚠️  Delete entire cluster and Docker resources"
	@echo "  clean           🧹 Alias for remove-complete"
	@echo ""
	@echo -e "$(CYAN)☁️  CLOUDFLARE DNS:$(NC)"
	@echo "  cloudflare-dns  🌐 Interactive DNS management with domain dropdown"
	@echo "  test-cloudflare 🧪 Test Cloudflare API connectivity"
	@echo ""
	@echo -e "$(CYAN)🔍 MONITORING & ACCESS:$(NC)"
	@echo "  status          📊 Show comprehensive deployment status"
	@echo "  validate        ✅ Validate deployments and health checks"
	@echo "  kibana          📈 Access Kibana dashboard (port-forward)"
	@echo "  elasticsearch   🔍 Access Elasticsearch API (port-forward)"
	@echo "  awx             🎭 Access AWX web interface (port-forward)"
	@echo "  awx-status      🎭 Check AWX deployment status"
	@echo "  logs            📋 View application and ELK logs"
	@echo "  kibana          📈 Access Kibana dashboard (port-forward)"
	@echo "  elasticsearch   🔍 Access Elasticsearch API (port-forward)"
	@echo "  logs            📋 View application and ELK logs"
	@echo ""
	@echo -e "$(CYAN)💾 BACKUP & RESTORE:$(NC)"
	@echo "  backup          💾 Create backup of current deployment"
	@echo "  restore         🔄 List and restore from backups"
	@echo ""
	@echo -e "$(CYAN)🧪 TESTING & UTILITIES:$(NC)"
	@echo "  generate-logs   📝 Generate sample logs for testing"
	@echo "  port-forwards   🌐 Setup all port forwards for local access"
	@echo "  info            ℹ️  Show cluster and deployment information"
	@echo ""
	@echo -e "$(YELLOW)📖 EXAMPLES:$(NC)"
	@echo "  make setup                          # Complete environment setup"
	@echo "  make deploy-complete                # Deploy everything with defaults"
	@echo "  make deploy-elk EXPOSE_SERVICES=false  # Deploy ELK without external access"
	@echo "  make remove-apps                    # Remove only application services"
	@echo "  make cloudflare-dns                 # Manage DNS records interactively"
	@echo ""
	@echo -e "$(YELLOW)🔧 CONFIGURATION:$(NC)"
	@echo "  DEPLOYMENT_MODE:      $(DEPLOYMENT_MODE) (complete, elk-only, apps-only)"
	@echo "  ELK_NAMESPACE:        $(ELK_NAMESPACE)"
	@echo "  APP_NAMESPACE:        $(APP_NAMESPACE)"
	@echo "  EXPOSE_SERVICES:      $(EXPOSE_SERVICES)"
	@echo "  ELASTICSEARCH_MEMORY: $(ELASTICSEARCH_MEMORY)"
	@echo ""

# =============================================================================
# SETUP AND PREREQUISITES
# =============================================================================
setup-python:
	@echo -e "$(BLUE)🐍 Setting up Python environment...$(NC)"
	@if command -v python3.13 >/dev/null 2>&1; then \
		echo -e "$(GREEN)✅ Python 3.13 found$(NC)"; \
	else \
		echo -e "$(RED)❌ Python 3.13 not found. Please install Python 3.13$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)📦 Installing Python packages...$(NC)"
	@$(PYTHON_CMD) -m pip install --upgrade pip
	@$(PYTHON_CMD) -m pip install -r requirements.txt
	@echo -e "$(GREEN)✅ Python environment configured successfully$(NC)"

setup-cluster:
	@echo -e "$(BLUE)⚙️  Setting up Kind Kubernetes cluster...$(NC)"
	@if ! command -v kind >/dev/null 2>&1; then \
		echo -e "$(RED)❌ Kind not found. Installing Kind...$(NC)"; \
		curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64; \
		chmod +x ./kind; \
		sudo mv ./kind /usr/local/bin/kind; \
	fi
	@$(SCRIPTS_DIR)/setup-kind.sh
	@echo -e "$(GREEN)✅ Kubernetes cluster setup completed$(NC)"

setup: setup-python setup-cluster
	@echo -e "$(GREEN)🎉 Complete setup finished successfully!$(NC)"

install-deps:
	@echo -e "$(BLUE)📦 Installing system dependencies...$(NC)"
	@if command -v brew >/dev/null 2>&1; then \
		brew install kind kubectl helm ansible; \
	else \
		echo -e "$(RED)❌ Homebrew not found. Please install dependencies manually$(NC)"; \
		echo "Required: kind, kubectl, helm, ansible"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)✅ Dependencies installed$(NC)"

check-env:
	@echo -e "$(BLUE)🔍 Checking environment...$(NC)"
	@echo -e "$(CYAN)System Dependencies:$(NC)"
	@for cmd in kubectl kind helm ansible python3.13; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo -e "  ✅ $$cmd: $$(command -v $$cmd)"; \
		else \
			echo -e "  ❌ $$cmd: Not found"; \
		fi; \
	done
	@echo -e "$(CYAN)Kubernetes Cluster:$(NC)"
	@if kubectl cluster-info >/dev/null 2>&1; then \
		echo -e "  ✅ Cluster: Accessible"; \
		echo -e "  📊 Nodes: $$(kubectl get nodes --no-headers | wc -l | tr -d ' ')"; \
	else \
		echo -e "  ❌ Cluster: Not accessible"; \
	fi
	@echo -e "$(CYAN)Python Environment:$(NC)"
	@if $(PYTHON_CMD) -c "import ansible, kubernetes, yaml" >/dev/null 2>&1; then \
		echo -e "  ✅ Python packages: Available"; \
	else \
		echo -e "  ❌ Python packages: Missing (run 'make setup-python')"; \
	fi

# =============================================================================
# DEPLOYMENT TARGETS
# =============================================================================
deploy-complete:
	@echo -e "$(BLUE)🚀 Deploying complete infrastructure...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/deploy.sh
	@$(SCRIPTS_DIR)/deploy.sh \
		--mode complete \
		--elk-namespace $(ELK_NAMESPACE) \
		--app-namespace $(APP_NAMESPACE) \
		--expose-services $(EXPOSE_SERVICES) \
		--cleanup-first $(CLEANUP_FIRST)

deploy-elk:
	@echo -e "$(BLUE)📊 Deploying ELK stack...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/deploy.sh
	@$(SCRIPTS_DIR)/deploy.sh \
		--mode elk-only \
		--elk-namespace $(ELK_NAMESPACE) \
		--expose-services $(EXPOSE_SERVICES)

deploy-apps:
	@echo -e "$(BLUE)🚀 Deploying application services...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/deploy.sh
	@$(SCRIPTS_DIR)/deploy.sh \
		--mode apps-only \
		--app-namespace $(APP_NAMESPACE) \
		--expose-services $(EXPOSE_SERVICES)

deploy-awx:
	@echo -e "$(BLUE)🎭 Deploying AWX with templates...$(NC)"
	@export ANSIBLE_HOST_KEY_CHECKING=False && \
	ansible-playbook $(AUTOMATION_DIR)/deploy-awx.yml \
		-e awx_namespace=awx \
		-e awx_admin_password=$(AWX_PASSWORD) \
		-e setup_templates=true \
		-e cloudflare_api_token=$(CLOUDFLARE_API_TOKEN)

deploy: deploy-complete

# =============================================================================
# CLEANUP TARGETS
# =============================================================================
remove-complete:
	@echo -e "$(BLUE)🧹 Removing complete infrastructure...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/cleanup.sh
	@$(SCRIPTS_DIR)/cleanup.sh \
		--mode complete \
		--elk-namespace $(ELK_NAMESPACE) \
		--app-namespace $(APP_NAMESPACE) \
		--metallb-namespace $(METALLB_NAMESPACE)

remove-elk:
	@echo -e "$(BLUE)🧹 Removing ELK stack...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/cleanup.sh
	@$(SCRIPTS_DIR)/cleanup.sh \
		--mode elk-only \
		--elk-namespace $(ELK_NAMESPACE)

remove-apps:
	@echo -e "$(BLUE)🧹 Removing application services...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/cleanup.sh
	@$(SCRIPTS_DIR)/cleanup.sh \
		--mode apps-only \
		--app-namespace $(APP_NAMESPACE)

clean-cluster:
	@echo -e "$(RED)⚠️  WARNING: This will delete the entire cluster!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		chmod +x $(SCRIPTS_DIR)/cleanup.sh; \
		$(SCRIPTS_DIR)/cleanup.sh --mode cluster --force; \
	else \
		echo "Cancelled."; \
	fi

clean: remove-complete

# =============================================================================
# CLOUDFLARE DNS MANAGEMENT
# =============================================================================
cloudflare-dns:
	@echo -e "$(BLUE)🌐 Starting Cloudflare DNS management...$(NC)"
	@if [ -z "$$CLOUDFLARE_API_TOKEN" ]; then \
		echo -e "$(RED)❌ CLOUDFLARE_API_TOKEN environment variable not set$(NC)"; \
		echo -e "$(YELLOW)Please export your Cloudflare API token:$(NC)"; \
		echo "export CLOUDFLARE_API_TOKEN=your_token_here"; \
		exit 1; \
	fi
	@ansible-playbook $(AUTOMATION_DIR)/cloudflare-dns-dynamic.yml

test-cloudflare:
	@echo -e "$(BLUE)🧪 Testing Cloudflare API connectivity...$(NC)"
	@if [ -z "$$CLOUDFLARE_API_TOKEN" ]; then \
		echo -e "$(RED)❌ CLOUDFLARE_API_TOKEN not set$(NC)"; \
		exit 1; \
	fi
	@curl -s -H "Authorization: Bearer $$CLOUDFLARE_API_TOKEN" \
		"https://api.cloudflare.com/client/v4/user" | \
		python3 -m json.tool | head -10

# =============================================================================
# MONITORING AND ACCESS
# =============================================================================
status:
	@echo -e "$(BLUE)📊 Deployment Status Overview$(NC)"
	@echo -e "$(PURPLE)================================$(NC)"
	@echo ""
	@echo -e "$(CYAN)🔹 Cluster Information:$(NC)"
	@kubectl cluster-info | head -1 || echo "❌ Cluster not accessible"
	@echo ""
	@echo -e "$(CYAN)🔹 Namespaces:$(NC)"
	@kubectl get namespaces | grep -E "($(ELK_NAMESPACE)|$(APP_NAMESPACE)|$(METALLB_NAMESPACE))" || echo "No application namespaces found"
	@echo ""
	@echo -e "$(CYAN)🔹 Pods Status:$(NC)"
	@kubectl get pods --all-namespaces | grep -E "($(ELK_NAMESPACE)|$(APP_NAMESPACE)|$(METALLB_NAMESPACE))" || echo "No application pods found"
	@echo ""
	@echo -e "$(CYAN)🔹 Services:$(NC)"
	@kubectl get svc --all-namespaces | grep -E "($(ELK_NAMESPACE)|$(APP_NAMESPACE)|LoadBalancer)" || echo "No external services found"
	@echo ""

validate:
	@echo -e "$(BLUE)✅ Running deployment validation...$(NC)"
	@echo -e "$(CYAN)Checking ELK Stack...$(NC)"
	@kubectl get pods -n $(ELK_NAMESPACE) 2>/dev/null || echo "ELK namespace not found"
	@echo -e "$(CYAN)Checking Application Services...$(NC)"
	@kubectl get pods -n $(APP_NAMESPACE) 2>/dev/null || echo "App namespace not found"
	@echo -e "$(CYAN)Checking Service Health...$(NC)"
	@kubectl get svc --all-namespaces -o wide | grep -E "(LoadBalancer|ClusterIP)" | head -5

kibana:
	@echo -e "$(BLUE)📈 Accessing Kibana dashboard...$(NC)"
	@pkill -f "kubectl port-forward.*5601" 2>/dev/null || true
	@sleep 2
	@echo -e "$(GREEN)🌐 Kibana available at: http://localhost:5601$(NC)"
	@echo -e "$(YELLOW)Press Ctrl+C to stop port forwarding$(NC)"
	@kubectl port-forward -n $(ELK_NAMESPACE) svc/kibana 5601:5601

elasticsearch:
	@echo -e "$(BLUE)🔍 Accessing Elasticsearch API...$(NC)"
	@pkill -f "kubectl port-forward.*9200" 2>/dev/null || true
	@sleep 2
	@echo -e "$(GREEN)🌐 Elasticsearch available at: http://localhost:9200$(NC)"
	@echo -e "$(YELLOW)Press Ctrl+C to stop port forwarding$(NC)"
	@kubectl port-forward -n $(ELK_NAMESPACE) svc/elasticsearch 9200:9200

awx:
	@echo -e "$(BLUE)🎭 Accessing AWX web interface...$(NC)"
	@pkill -f "kubectl port-forward.*30080" 2>/dev/null || true
	@sleep 2
	@echo -e "$(GREEN)🌐 AWX available at: http://localhost:30080$(NC)"
	@echo -e "$(CYAN)Default credentials: admin / $(AWX_PASSWORD)$(NC)"
	@echo -e "$(YELLOW)Press Ctrl+C to stop port forwarding$(NC)"
	@kubectl port-forward -n awx svc/awx-service 30080:80

awx-status:
	@echo -e "$(BLUE)🎭 AWX Status Check...$(NC)"
	@echo -e "$(CYAN)AWX Pods:$(NC)"
	@kubectl get pods -n awx 2>/dev/null || echo "AWX not deployed"
	@echo -e "$(CYAN)AWX Services:$(NC)"
	@kubectl get svc -n awx 2>/dev/null || echo "AWX services not found"
	@echo -e "$(CYAN)AWX Job Templates:$(NC)"
	@kubectl get configmap awx-job-templates -n awx -o jsonpath='{.data}' 2>/dev/null || echo "Job templates not configured"
	@sleep 2
	@echo -e "$(GREEN)🔗 Elasticsearch available at: http://localhost:9200$(NC)"
	@echo -e "$(YELLOW)Test with: curl http://localhost:9200/_cluster/health$(NC)"
	@echo -e "$(YELLOW)Press Ctrl+C to stop port forwarding$(NC)"
	@kubectl port-forward -n $(ELK_NAMESPACE) svc/elasticsearch 9200:9200

logs:
	@echo -e "$(BLUE)📋 Viewing recent logs...$(NC)"
	@echo -e "$(CYAN)ELK Stack Logs:$(NC)"
	@kubectl logs -n $(ELK_NAMESPACE) -l app=elasticsearch --tail=10 --prefix=true 2>/dev/null || echo "No Elasticsearch logs"
	@kubectl logs -n $(ELK_NAMESPACE) -l app=kibana --tail=10 --prefix=true 2>/dev/null || echo "No Kibana logs"
	@echo ""
	@echo -e "$(CYAN)Application Logs:$(NC)"
	@kubectl logs -n $(APP_NAMESPACE) -l app=order-service --tail=10 --prefix=true 2>/dev/null || echo "No Order Service logs"
	@kubectl logs -n $(APP_NAMESPACE) -l app=user-service --tail=10 --prefix=true 2>/dev/null || echo "No User Service logs"

# =============================================================================
# BACKUP AND RESTORE
# =============================================================================
backup:
	@echo -e "$(BLUE)💾 Creating deployment backup...$(NC)"
	@mkdir -p ./backups/$$(date +%Y%m%d_%H%M%S)
	@kubectl get all,pvc,configmap,secret -n $(ELK_NAMESPACE) -o yaml > ./backups/$$(date +%Y%m%d_%H%M%S)/elk-backup.yaml 2>/dev/null || true
	@kubectl get all,pvc,configmap,secret -n $(APP_NAMESPACE) -o yaml > ./backups/$$(date +%Y%m%d_%H%M%S)/app-backup.yaml 2>/dev/null || true
	@echo -e "$(GREEN)✅ Backup created in ./backups/$(NC)"

restore:
	@echo -e "$(BLUE)🔄 Available backups:$(NC)"
	@ls -la ./backups/ 2>/dev/null || echo "No backups found"
	@echo ""
	@echo -e "$(YELLOW)To restore a backup:$(NC)"
	@echo "kubectl apply -f ./backups/<backup-date>/elk-backup.yaml"
	@echo "kubectl apply -f ./backups/<backup-date>/app-backup.yaml"

# =============================================================================
# TESTING AND UTILITIES
# =============================================================================
generate-logs:
	@echo -e "$(BLUE)📝 Generating sample logs...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/generate-sample-logs.sh
	@$(SCRIPTS_DIR)/generate-sample-logs.sh &
	@echo -e "$(GREEN)✅ Sample log generator started in background$(NC)"

port-forwards:
	@echo -e "$(BLUE)🌐 Setting up port forwards...$(NC)"
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	@sleep 2
	@echo -e "$(GREEN)Starting port forwards:$(NC)"
	@echo -e "  📈 Kibana: http://localhost:5601"
	@echo -e "  🔍 Elasticsearch: http://localhost:9200"
	@kubectl port-forward -n $(ELK_NAMESPACE) svc/kibana 5601:5601 > /dev/null 2>&1 &
	@kubectl port-forward -n $(ELK_NAMESPACE) svc/elasticsearch 9200:9200 > /dev/null 2>&1 &
	@sleep 3
	@echo -e "$(YELLOW)Port forwards are running in background$(NC)"
	@echo -e "$(YELLOW)To stop: pkill -f 'kubectl port-forward'$(NC)"

info:
	@echo -e "$(BLUE)ℹ️  Cluster and Deployment Information$(NC)"
	@echo -e "$(PURPLE)=======================================$(NC)"
	@echo ""
	@echo -e "$(CYAN)📊 Cluster Details:$(NC)"
	@kubectl version --short 2>/dev/null || echo "Unable to get version"
	@kubectl get nodes -o wide 2>/dev/null || echo "Unable to get nodes"
	@echo ""
	@echo -e "$(CYAN)💾 Resource Usage:$(NC)"
	@kubectl top nodes 2>/dev/null || echo "Metrics server not available"
	@echo ""
	@echo -e "$(CYAN)🔧 Configuration:$(NC)"
	@echo "  ELK Namespace: $(ELK_NAMESPACE)"
	@echo "  App Namespace: $(APP_NAMESPACE)"
	@echo "  Storage Class: $(STORAGE_CLASS)"
	@echo "  Elasticsearch Memory: $(ELASTICSEARCH_MEMORY)"
	@echo ""

# =============================================================================
# LEGACY COMPATIBILITY (maintain old targets)
# =============================================================================
legacy-setup:
	@echo -e "$(YELLOW)⚠️  Using legacy setup. Consider 'make setup' instead$(NC)"
	@$(SCRIPTS_DIR)/setup-kubespray.sh

legacy-clean:
	@echo -e "$(YELLOW)⚠️  Using legacy clean. Consider 'make clean' instead$(NC)"
	@cd $(KUBESPRAY_DIR) && \
		ansible-playbook -i $(INVENTORY) --become reset.yml

legacy-deploy:
	@echo -e "$(YELLOW)⚠️  Using legacy deploy. Consider 'make deploy' instead$(NC)"
	@ansible-playbook playbooks/main.yml -e action=deploy

legacy-remove:
	@echo -e "$(YELLOW)⚠️  Using legacy remove. Consider 'make remove-complete' instead$(NC)"
	@ansible-playbook playbooks/main.yml -e action=remove
