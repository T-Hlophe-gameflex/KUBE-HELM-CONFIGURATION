# Inventory Configuration

Kubernetes cluster inventory for Kubespray and Ansible automation.

## Files

- `mycluster/hosts.yaml` - Kind cluster configuration

## Usage

```bash
ansible-playbook -i inventory/mycluster/hosts.yaml playbooks/main.yml -e action=deploy
```
