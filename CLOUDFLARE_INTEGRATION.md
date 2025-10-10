# Cloudflare Integration & Testing Guide

This guide walks you through integrating your actual Cloudflare account with the AWX setup and testing the DNS automation.

## Prerequisites

- Cloudflare account with at least one domain
- AWX deployed and accessible
- kubectl and helm configured

## Step 1: Get Your Cloudflare API Token

### Option A: Create API Token (Recommended)

1. **Log into Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com/
   - Navigate to "My Profile" → "API Tokens"

2. **Create Custom Token**
   - Click "Create Token"
   - Use "Edit zone DNS" template or create custom
   - **Permissions**:
     - Zone:Zone:Read
     - Zone:DNS:Edit
   - **Zone Resources**:
     - Include: All zones (or specific zones you want to manage)
   - **Client IP Address Filtering**: Optional (your IP for security)

3. **Save the Token**
   ```bash
   # Example token format
   export CLOUDFLARE_API_TOKEN="your-api-token-here"
   ```

### Option B: Use Global API Key (Legacy)

1. **Get Global API Key**
   - Go to "My Profile" → "API Tokens"
   - Click "View" next to Global API Key
   - Copy the key

2. **Set Environment Variables**
   ```bash
   export CLOUDFLARE_EMAIL="your-email@example.com"
   export CLOUDFLARE_API_KEY="your-global-api-key"
   ```

## Step 2: Test Cloudflare API Connectivity

```bash
# Test with API Token
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json"

# Test with Global API Key
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
     -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
     -H "Content-Type: application/json"
```

Expected response should list your zones:
```json
{
  "success": true,
  "errors": [],
  "messages": [],
  "result": [
    {
      "id": "zone-id-here",
      "name": "yourdomain.com",
      "status": "active"
    }
  ]
}
```

## Step 3: Deploy and Configure AWX

### Deploy AWX
```bash
# Navigate to project directory
cd /path/to/KUBE-HELM-CONFIGURATION

# Deploy AWX
ansible-playbook playbooks/main.yml -e deploy_awx=true

# Wait for AWX to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=awx -n awx --timeout=900s
```

### Get AWX Access Details
```bash
# Get admin password
AWX_PASSWORD=$(kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode)
echo "AWX Admin Password: $AWX_PASSWORD"

# Get AWX URL
kubectl get svc -n awx
# Look for ansible-awx-service NodePort (usually 30080)
echo "AWX URL: http://<your-node-ip>:30080"
```

## Step 4: Set Up AWX Configuration

### Option A: Automated Setup
```bash
# Install AWX CLI
pip install awxkit

# Configure environment
export AWX_HOST="http://<your-node-ip>:30080"
export AWX_USERNAME="admin"
export AWX_PASSWORD="$AWX_PASSWORD"

# Run automated setup
cd helm-charts/charts/awx/config
chmod +x setup-awx-cloudflare.sh
./setup-awx-cloudflare.sh
```

### Option B: Manual Setup

1. **Access AWX Web Interface**
   - URL: `http://<node-ip>:30080`
   - Username: `admin`
   - Password: (from Step 3)

2. **Create Organization**
   - Go to Access → Organizations
   - Click "+" to add new
   - Name: "Cloudflare Operations"

3. **Create Credential Type** (if not using automated setup)
   - Go to Administration → Credential Types
   - Click "+" to add new
   - Name: "Cloudflare API"
   - Input Configuration:
   ```yaml
   fields:
     - id: api_token
       type: string
       label: Cloudflare API Token
       secret: true
     - id: email
       type: string
       label: Cloudflare Email
     - id: global_api_key
       type: string
       label: Global API Key
       secret: true
   ```
   - Injector Configuration:
   ```yaml
   env:
     CLOUDFLARE_API_TOKEN: '{{ api_token }}'
     CLOUDFLARE_EMAIL: '{{ email }}'
     CLOUDFLARE_API_KEY: '{{ global_api_key }}'
   ```

4. **Create Cloudflare Credentials**
   - Go to Resources → Credentials
   - Click "+" to add new
   - Name: "Cloudflare API Credentials"
   - Credential Type: "Cloudflare API"
   - Fill in your API token OR email + global API key

## Step 5: Create Project and Playbooks

### Option A: Use Git Repository
```bash
# Create a Git repository with your playbooks
mkdir cloudflare-automation
cd cloudflare-automation

# Copy playbooks
cp /path/to/KUBE-HELM-CONFIGURATION/helm-charts/charts/awx/config/*.yml .

# Initialize git and push to your repository
git init
git add .
git commit -m "Initial cloudflare playbooks"
git remote add origin https://github.com/yourusername/cloudflare-automation.git
git push -u origin main
```

In AWX:
- Go to Resources → Projects
- Click "+" to add new
- Name: "Cloudflare DNS Project"
- SCM Type: Git
- SCM URL: Your repository URL

### Option B: Local Project
```bash
# Copy playbooks to AWX project directory
kubectl exec -n awx deployment/ansible-awx-web -- mkdir -p /var/lib/awx/projects/cloudflare
kubectl cp helm-charts/charts/awx/config/cloudflare-dns-playbook.yml awx/ansible-awx-web:/var/lib/awx/projects/cloudflare/
kubectl cp helm-charts/charts/awx/config/cloudflare-zone-info.yml awx/ansible-awx-web:/var/lib/awx/projects/cloudflare/
```

In AWX:
- Go to Resources → Projects
- Click "+" to add new
- Name: "Cloudflare DNS Project"
- SCM Type: Manual
- Project Path: `/var/lib/awx/projects/cloudflare`

## Step 6: Update Domain Configuration

### Edit Job Template Survey
1. **Go to Resources → Templates**
2. **Find "Cloudflare DNS Management"**
3. **Click on the template name**
4. **Go to "Survey" tab**
5. **Edit "Domain Selection" question**
6. **Update choices to include your actual domains**:
   ```
   yourdomain.com
   subdomain.yourdomain.com
   anotherdomain.com
   ```

## Step 7: Test the Integration

### Test 1: Zone Information
1. **Launch "Cloudflare Zone Info" template**
2. **Select your domain**
3. **Execute and verify it lists your DNS records**

### Test 2: Create a Test DNS Record
1. **Launch "Cloudflare DNS Management" template**
2. **Fill out the survey**:
   - Domain: `yourdomain.com`
   - Operation: `create`
   - Record Name: `awx-test`
   - Record Type: `A`
   - Record Value: `192.168.1.100`
   - TTL: `300`
   - Proxied: `false`
3. **Execute the job**
4. **Verify in Cloudflare dashboard that the record was created**

### Test 3: Bulk Record Creation
1. **Launch "Cloudflare DNS Management" template**
2. **Select "bulk_create" operation**
3. **Use this JSON in bulk records field** (adjust for your domain):
```json
[
  {
    "name": "api-test",
    "type": "A",
    "value": "192.168.1.101",
    "ttl": 300,
    "proxied": true
  },
  {
    "name": "mail-test",
    "type": "A",
    "value": "192.168.1.102",
    "ttl": 3600,
    "proxied": false
  }
]
```

### Test 4: Update and Delete Records
1. **Update**: Change the value of your test record
2. **Delete**: Remove the test records you created

## Step 8: Advanced Testing

### Test with Real Infrastructure
```bash
# Get your actual server IP
MY_SERVER_IP=$(curl -s ifconfig.me)

# Create a record pointing to your actual server
# Use this in the AWX survey:
# - Name: "server"
# - Type: "A"  
# - Value: "$MY_SERVER_IP"
# - Proxied: true (for web traffic)
```

### Test Scheduled Jobs
1. **Edit Cloudflare chart values**:
```yaml
# In helm-charts/charts/cloudflare/values.yaml
job:
  schedule: "*/5 * * * *"  # Every 5 minutes
cloudflare:
  domain: "yourdomain.com"
  dnsRecords:
    - name: "heartbeat"
      type: "TXT"
      value: "Last updated: $(date)"
      ttl: 300
```

2. **Deploy the scheduled job**:
```bash
helm upgrade --install cloudflare-scheduled ./helm-charts/charts/cloudflare \
  --set cloudflare.apiToken="$CLOUDFLARE_API_TOKEN" \
  --set cloudflare.domain="yourdomain.com" \
  --set job.schedule="*/5 * * * *" \
  -n dns-automation --create-namespace
```

## Troubleshooting

### API Authentication Issues
```bash
# Verify token permissions
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Check zone access
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

### AWX Job Failures
```bash
# Check AWX logs
kubectl logs -n awx deployment/ansible-awx-task
kubectl logs -n awx deployment/ansible-awx-web

# Check job output in AWX web interface
# Go to Views → Jobs → Click on failed job → View output
```

### DNS Propagation
```bash
# Check if DNS record was created
dig awx-test.yourdomain.com

# Check from different DNS servers
dig @8.8.8.8 awx-test.yourdomain.com
dig @1.1.1.1 awx-test.yourdomain.com
```

## Security Best Practices

### API Token Security
1. **Use minimal permissions** (only Zone:DNS:Edit)
2. **Restrict to specific zones** you need to manage
3. **Set IP restrictions** if possible
4. **Rotate tokens regularly**

### AWX Security
1. **Create separate users** for different team members
2. **Use RBAC** to limit access to specific templates
3. **Audit job executions** regularly
4. **Backup AWX database** periodically

## Next Steps

1. **Integrate with CI/CD**: Use AWX API for automated deployments
2. **Create monitoring**: Set up alerts for DNS changes
3. **Extend automation**: Add more DNS management features
4. **Documentation**: Document your specific domain configurations
5. **Backup strategy**: Export AWX configurations and Cloudflare settings