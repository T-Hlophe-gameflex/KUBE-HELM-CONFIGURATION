# 🚀 Quick Start: Test Cloudflare Integration

Follow these steps to quickly test the Cloudflare + AWX integration:

## Step 1: Get Your Cloudflare API Token

1. **Go to Cloudflare Dashboard**: https://dash.cloudflare.com/profile/api-tokens
2. **Click "Create Token"**
3. **Use "Edit zone DNS" template** or create custom with:
   - Zone:Zone:Read
   - Zone:DNS:Edit
   - Include: All zones (or specific zones)
4. **Copy the token** (you'll need it below)

## Step 2: Quick Test with Helm Chart

```bash
# Navigate to the project directory
cd KUBE-HELM-CONFIGURATION

# Set your Cloudflare credentials
export CLOUDFLARE_API_TOKEN="your-token-here"
export YOUR_DOMAIN="yourdomain.com"  # Replace with your actual domain

# Test Cloudflare API access
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json"

# Should return JSON with your zones
```

## Step 3: Deploy AWX

```bash
# Deploy AWX using Ansible
ansible-playbook playbooks/main.yml -e deploy_awx=true

# Wait for AWX to be ready (this may take 5-10 minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=awx -n awx --timeout=900s

# Get AWX admin password
kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode
echo  # Add newline

# Get AWX URL
kubectl get svc -n awx
# Look for NodePort (usually 30080)
```

## Step 4: Test Direct Cloudflare Chart

```bash
# Create a test DNS record using the Cloudflare chart
helm upgrade --install cloudflare-test ./helm-charts/charts/cloudflare \
  --set cloudflare.apiToken="$CLOUDFLARE_API_TOKEN" \
  --set cloudflare.domain="$YOUR_DOMAIN" \
  --set cloudflare.dnsRecords[0].name="helm-test" \
  --set cloudflare.dnsRecords[0].type="TXT" \
  --set cloudflare.dnsRecords[0].value="Test from Helm - $(date)" \
  --set job.ttlSecondsAfterFinished=300 \
  -n dns-automation --create-namespace

# Check the job status
kubectl get jobs -n dns-automation
kubectl logs job/cloudflare-test-job -n dns-automation

# Verify the DNS record was created
dig helm-test.$YOUR_DOMAIN TXT
```

## Step 5: Access AWX Web Interface

```bash
# Get connection details
echo "AWX URL: http://<your-node-ip>:$(kubectl get svc -n awx -o jsonpath='{.items[0].spec.ports[0].nodePort}')"
echo "Username: admin"
echo "Password: $(kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode)"
```

1. **Open your browser** and go to the AWX URL
2. **Log in** with admin credentials
3. **Navigate to Resources → Credentials**
4. **Create new credential**:
   - Name: "Cloudflare API"
   - Type: Create custom type or use existing
   - Add your API token

## Step 6: Quick AWX Job Template Test

### Manual Creation (Fastest)

1. **Go to Resources → Templates**
2. **Click "+"** to add new job template
3. **Configure**:
   - Name: "Test Cloudflare DNS"
   - Job Type: Run
   - Inventory: Demo Inventory (or create localhost)
   - Project: Create a project or use demo
   - Playbook: Create a simple test playbook

### Test Playbook Content

Create this simple playbook for testing:

```yaml
---
- name: Test Cloudflare DNS
  hosts: localhost
  connection: local
  gather_facts: false
  
  tasks:
    - name: Install Cloudflare collection
      ansible.builtin.command:
        cmd: ansible-galaxy collection install cloudflare.cloudflare --force
      
    - name: Create test DNS record
      cloudflare.cloudflare.cloudflare_dns:
        zone: "{{ cloudflare_domain | default('yourdomain.com') }}"
        record: "{{ record_name | default('awx-test') }}"
        type: "{{ record_type | default('TXT') }}"
        value: "{{ record_value | default('AWX Test - ' + ansible_date_time.iso8601) }}"
        ttl: 300
        api_token: "{{ ansible_env.CLOUDFLARE_API_TOKEN }}"
        state: present
      register: dns_result
      
    - name: Show result
      debug:
        var: dns_result
```

## Step 7: Automated Setup (Advanced)

If you want to fully automate the AWX configuration:

```bash
# Install AWX CLI
pip install awxkit

# Set environment variables
export AWX_HOST="http://<your-node-ip>:30080"
export AWX_USERNAME="admin"
export AWX_PASSWORD="<from-step-3>"

# Run the automated setup script
cd helm-charts/charts/awx/config
chmod +x setup-awx-cloudflare.sh
./setup-awx-cloudflare.sh
```

## Troubleshooting

### Common Issues

1. **"Token invalid" errors**
   - Verify token has Zone:DNS:Edit permissions
   - Check token hasn't expired
   - Ensure you're using the correct token format

2. **AWX pods not starting**
   - Check if storage directory exists: `ls -la /mnt/awx-storage`
   - Create if missing: `sudo mkdir -p /mnt/awx-storage && sudo chmod 755 /mnt/awx-storage`

3. **Job fails with "collection not found"**
   - The playbook automatically installs collections
   - Check internet connectivity from AWX pods

4. **DNS record not visible immediately**
   - DNS propagation can take a few minutes
   - Check in Cloudflare dashboard first
   - Use different DNS servers: `dig @8.8.8.8` or `dig @1.1.1.1`

### Debug Commands

```bash
# Check AWX status
kubectl get pods -n awx
kubectl logs -n awx deployment/ansible-awx-web
kubectl logs -n awx deployment/ansible-awx-task

# Check Cloudflare job logs
kubectl logs job/cloudflare-test-job -n dns-automation

# Test API directly
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

## Success Verification

You'll know the integration is working when:

1. ✅ **Cloudflare API** responds with your zones
2. ✅ **AWX deploys** successfully and is accessible
3. ✅ **Helm chart** creates DNS records
4. ✅ **AWX job templates** execute without errors
5. ✅ **DNS records** appear in Cloudflare dashboard
6. ✅ **DNS queries** return the created records

## Next Steps

Once basic integration is working:

1. **Customize surveys** with your actual domains
2. **Create user accounts** with limited permissions  
3. **Set up monitoring** for job failures
4. **Integrate with CI/CD** using AWX API
5. **Create scheduled jobs** for recurring tasks

## Quick Test Script

For an automated test, run:

```bash
./test-cloudflare-integration.sh
```

This script will guide you through the entire process interactively.