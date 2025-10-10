# Quick Start Deployment Guide

This guide walks you through deploying the complete infrastructure including ELK Stack, AWX, and Cloudflare DNS automation.

## Prerequisites

- Kubernetes cluster (local or cloud)
- Helm 3.x installed
- kubectl configured
- Ansible installed (for playbook execution)

## Step 1: Deploy Everything with Ansible

The easiest way is to use the provided Ansible playbooks:

```bash
# Clone the repository
git clone https://github.com/T-Hlophe-gameflex/KUBE-HELM-CONFIGURATION.git
cd KUBE-HELM-CONFIGURATION

# Deploy the full stack (including AWX)
ansible-playbook playbooks/main.yml -e deploy_awx=true

# Or deploy specific components
ansible-playbook playbooks/main.yml -e deploy_awx=true -e deploy_postgres=true -e deploy_metallb=true
```

## Step 2: Access AWX

```bash
# Wait for AWX to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=awx -n awx --timeout=600s

# Get AWX admin password
AWX_PASSWORD=$(kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode)
echo "AWX Admin Password: $AWX_PASSWORD"

# Get AWX URL
AWX_URL=$(kubectl get svc -n awx | grep ansible-awx-service | awk '{print $5}' | sed 's/:/ /')
echo "AWX URL: http://<node-ip>:$AWX_URL"
```

## Step 3: Configure AWX for Cloudflare

### Option A: Automated Setup

```bash
# Install AWX CLI
pip install awxkit

# Set environment variables
export AWX_HOST="http://<your-node-ip>:30080"
export AWX_USERNAME="admin"
export AWX_PASSWORD="$AWX_PASSWORD"

# Run the automated setup
cd helm-charts/charts/awx/config
chmod +x setup-awx-cloudflare.sh
./setup-awx-cloudflare.sh
```

### Option B: Manual Setup

1. **Access AWX Web Interface**
   - URL: `http://<node-ip>:30080`
   - Username: `admin`
   - Password: (from Step 2)

2. **Create Cloudflare API Credential**
   - Go to Resources → Credentials
   - Click "+" to add new credential
   - Type: "Cloudflare API" (created by setup script)
   - Enter your Cloudflare API token

3. **Import Job Templates**
   - Use the configurations in `helm-charts/charts/awx/config/job-templates.yml`
   - Create project pointing to your playbook repository
   - Import the job templates with surveys

## Step 4: Test Cloudflare DNS Management

### Using AWX Web Interface

1. **Navigate to Templates**
   - Go to Resources → Templates
   - Click on "Cloudflare DNS Management"

2. **Launch Job with Survey**
   - Click the rocket icon to launch
   - Fill out the survey form:
     - Domain: Select from dropdown
     - Operation: Choose create/update/delete/bulk/list
     - Record details: name, type, value, TTL
     - Proxy setting: Enable/disable Cloudflare proxy

3. **Monitor Job Execution**
   - View real-time output
   - Check job status and results

### Using Helm Chart Directly

```bash
# Deploy Cloudflare job for single record
helm upgrade --install cloudflare-test ./charts/cloudflare \
  --set cloudflare.apiToken="your-api-token" \
  --set cloudflare.domain="example.com" \
  --set cloudflare.dnsRecords[0].name="test" \
  --set cloudflare.dnsRecords[0].type="A" \
  --set cloudflare.dnsRecords[0].value="192.168.1.100" \
  -n dns-automation --create-namespace

# Check job status
kubectl get jobs -n dns-automation
kubectl logs job/cloudflare-test-job -n dns-automation
```

## Step 5: Monitor and Manage

### Check Service Status
```bash
# ELK Stack
kubectl get pods -n monitoring

# AWX
kubectl get pods -n awx

# Services
kubectl get pods -n backend
kubectl get pods -n database
```

### Access Monitoring Dashboards
```bash
# Kibana for log analysis
kubectl port-forward -n monitoring svc/kibana 5601:5601
# Access: http://localhost:5601

# AWX for automation management
# Access: http://<node-ip>:30080
```

## Customization Examples

### Add New Domains to AWX Survey

1. Edit the job template in AWX
2. Go to Survey tab
3. Modify "Domain Selection" question
4. Add your domains to the choices list

### Create Recurring DNS Updates

```yaml
# In cloudflare values.yaml
job:
  schedule: "0 */6 * * *"  # Every 6 hours
cloudflare:
  dnsRecords:
    - name: "dynamic-ip"
      type: "A"
      value: "{{ ansible_default_ipv4.address }}"
      ttl: 300
```

### Bulk DNS Record Creation

Use this JSON in the AWX survey bulk records field:

```json
[
  {
    "name": "api",
    "type": "A",
    "value": "192.168.1.101",
    "ttl": 300,
    "proxied": true
  },
  {
    "name": "mail",
    "type": "A",
    "value": "192.168.1.102",
    "ttl": 3600,
    "proxied": false
  },
  {
    "name": "ftp",
    "type": "CNAME",
    "value": "api.example.com",
    "ttl": 300,
    "proxied": false
  }
]
```

## Troubleshooting

### AWX Issues
```bash
# Check AWX operator logs
kubectl logs -n awx deployment/awx-operator-controller-manager

# Check AWX instance logs
kubectl logs -n awx deployment/ansible-awx-web
kubectl logs -n awx deployment/ansible-awx-task
```

### Cloudflare Authentication
- Verify API token has DNS:Edit permissions
- Check token is not expired
- Ensure zones are accessible with the token

### Job Failures
- Check AWX job output for detailed errors
- Verify Cloudflare credentials in AWX
- Test API connectivity from AWX pods

## Next Steps

1. **Integrate with CI/CD**: Use AWX API to trigger DNS updates from pipelines
2. **Add Monitoring**: Set up alerts for job failures
3. **Extend Automation**: Create more playbooks for infrastructure management
4. **Security**: Implement RBAC and credential rotation
5. **Backup**: Set up AWX database backups and configuration exports