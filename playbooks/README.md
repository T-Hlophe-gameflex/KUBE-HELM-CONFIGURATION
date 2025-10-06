# Ansible Playbooks

Ansible automation for deploying Helm charts on Kubernetes.

## Flow

```text
Ansible → Helm → Kubernetes → MetalLB LoadBalancer
```

## Usage

```bash
# Deploy all charts
ansible-playbook playbooks/main.yml -e action=deploy

# Validate cluster
ansible-playbook playbooks/main.yml -e action=validate

# Remove all charts
ansible-playbook playbooks/main.yml -e action=remove

# Or use Makefile shortcuts
make deploy
make validate
make remove
```

## Task Files

- `tasks/deploy-helm.yml` - Deploy all Helm charts in order
- `tasks/remove-helm.yml` - Remove all releases in reverse order
- `tasks/validate-cluster.yml` - Check cluster health
