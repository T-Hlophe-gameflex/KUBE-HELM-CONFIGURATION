.PHONY: help setup clean deploy remove validate status info kibana logs generate-logs

KUBESPRAY_DIR := /Users/thami.hlophe/kubespray
INVENTORY := $(KUBESPRAY_DIR)/inventory/helm-kube-cluster/inventory.ini
NAMESPACE := monitoring

help:
	@echo "ELK Stack Platform - Kubespray Deployment"
	@echo "=========================================="
	@echo ""
	@echo "Cluster:"
	@echo "  setup      - Deploy Kubespray cluster + ELK + logs"
	@echo "  clean      - Destroy cluster"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy     - Deploy ELK stack (Ansible)"
	@echo "  remove     - Remove deployments"
	@echo "  validate   - Validate deployments"
	@echo ""
	@echo "Access:"
	@echo "  kibana     - Port-forward Kibana (5601)"
	@echo "  info       - Show cluster info"
	@echo "  status     - Show deployment status"
	@echo "  logs       - View logs"
	@echo ""
	@echo "Utilities:"
	@echo "  generate-logs - Start log generation"
	@echo ""

setup:
	@./scripts/setup-kubespray.sh

clean:
	@cd $(KUBESPRAY_DIR) && \
		ansible-playbook -i $(INVENTORY) --become reset.yml

deploy:
	@ansible-playbook playbooks/main.yml -e action=deploy

remove:
	@ansible-playbook playbooks/main.yml -e action=remove

validate:
	@ansible-playbook playbooks/main.yml -e action=validate

status:
	@kubectl get pods -A
	@echo ""
	@kubectl get svc -A

info:
	@kubectl cluster-info
	@echo ""
	@kubectl get nodes -o wide

kibana:
	@pkill -f "kubectl port-forward.*5601" 2>/dev/null || true
	@echo "Kibana: http://localhost:5601"
	@kubectl port-forward -n $(NAMESPACE) svc/kibana 5601:5601

logs:
	@kubectl logs -n backend -l app=order-service --tail=50
	@kubectl logs -n backend -l app=user-service --tail=50

generate-logs:
	@./scripts/generate-sample-logs.sh &
