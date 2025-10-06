.PHONY: help setup clean deploy remove validate status info kibana logs generate-logs

KUBESPRAY_DIR := /Users/thami.hlophe/kubespray
INVENTORY := $(KUBESPRAY_DIR)/inventory/helm-kube-cluster/inventory.ini
NAMESPACE := monitoring

help:
	@echo "ELK Stack Platform"
	@echo "=================="
	@echo ""
	@echo "Cluster:"
	@echo "  setup      - Deploy cluster"
	@echo "  clean      - Destroy cluster"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy     - Deploy ELK stack"
	@echo "  remove     - Remove deployments"
	@echo "  validate   - Validate deployments"
	@echo ""
	@echo "Access:"
	@echo "  kibana     - Port-forward Kibana"
	@echo "  status     - Show deployment status"
	@echo ""
	@echo "Utilities:"
	@echo "  generate-logs - Generate sample logs"

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
	@kubectl get svc -A

kibana:
	@pkill -f "kubectl port-forward.*5601" 2>/dev/null || true
	@echo "Kibana available at: http://localhost:5601"
	@kubectl port-forward -n $(NAMESPACE) svc/kibana 5601:5601

logs:
	@kubectl logs -n backend -l app=order-service --tail=20
	@kubectl logs -n backend -l app=user-service --tail=20

generate-logs:
	@./scripts/generate-sample-logs.sh &
