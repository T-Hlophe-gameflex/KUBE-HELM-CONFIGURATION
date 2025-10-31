# Quick Start Guide - AWX Cloudflare Automation

**Get up and running in 15 minutes!**

This guide will have you managing Cloudflare DNS through AWX in the fastest way possible.

---

## Prerequisites (5 min)

- **Kubernetes cluster** running (minikube, kind, k3s, or cloud)
- **kubectl** configured
- **make** installed
- **Cloudflare API token** ready

---

## Step 1: Get Your Cloudflare API Token (2 min)

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Click **"Create Token"**
3. Use template: **"Edit zone DNS"** or create custom with:
   - Zone - Zone - Read
   - Zone - DNS - Edit
4. Copy the token (you'll need it!)

---

## Step 2: Setup AWX Instance Config (2 min)

```bash
cd CF_AWX_AUTO

# Create AWX instance configuration
cat > config/awx-instance.yaml <<'EOF'
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ansible-awx
spec:
  service_type: ClusterIP
  ingress_type: none
  image: docker.io/blackthami/awx-cloudflare-auto
  image_version: 24.6.1-cf-auto
  
  web_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
  
  task_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
  
  postgres_storage_class: standard
  postgres_storage_requirements:
    requests:
      storage: 8Gi
EOF
```

---

## Step 3: Install Everything (5 min)

```bash
# One command to install it all!
make install-all CLOUDFLARE_API_TOKEN=your_token_here

# This will:
# - Install AWX Operator
# - Create Cloudflare secret
# - Deploy AWX instance
# - Wait for everything to be ready
```

**Note: This takes approximately 5 minutes to complete**

---

## Step 4: Access AWX (1 min)

```bash
# Get your admin password
make get-password
# Copy this password!

# Start port-forward (in another terminal or background)
make port-forward &

# Open browser: http://localhost:8052
# Login:
#   Username: admin
#   Password: (from above)
```

---

## Step 5: Create Initial Setup in AWX UI (3 min)

### 5a. Create Project

1. Go to **Resources** → **Projects**
2. Click **Add**
3. Fill in:
   - Name: `Cloudflare Automation`
   - Organization: `Default`
   - SCM Type: `Manual`
4. Click **Save**

### 5b. Copy Playbooks to AWX

```bash
# Get task pod name
TASK_POD=$(kubectl get pods -n awx -l app.kubernetes.io/component=task -o jsonpath='{.items[0].metadata.name}')

# Copy playbooks directory
kubectl cp playbooks/cloudflare $TASK_POD:/var/lib/awx/projects/_6__cloudflare_automation/ -n awx
```

### 5c. Create Inventory

1. Go to **Resources** → **Inventories**
2. Click **Add** → **Add inventory**
3. Fill in:
   - Name: `Localhost`
4. Click **Save**
5. Go to **Hosts** tab → Click **Add**
6. Fill in:
   - Name: `localhost`
   - Variables:
     ```yaml
     ansible_connection: local
     ansible_python_interpreter: /usr/bin/python3
     ```
7. Click **Save**

### 5d. Create Job Template

1. Go to **Resources** → **Templates**
2. Click **Add** → **Add job template**
3. Fill in:
   - Name: `Cloudflare - Automation`
   - Job Type: `Run`
   - Inventory: `Localhost`
   - Project: `Cloudflare Automation`
   - Playbook: `cloudflare/cloudflare_awx_playbook.yml`
   - Variables:
     ```yaml
     cloudflare_api_token: "{{ lookup('env', 'CLOUDFLARE_API_TOKEN') }}"
     ```
4. In **Execution Environment**, ensure `AWX EE` is selected
5. Click **Save**
6. **Note the template ID** from the URL (e.g., `/templates/job_template/21/`)

---

## Step 6: Configure Survey & Dropdowns (2 min)

```bash
# Apply survey configuration
make apply-survey

# Populate with your Cloudflare data
make update-dropdowns CLOUDFLARE_API_TOKEN=your_token_here
```

---

## Step 7: Test It! (2 min)

### Create Your First DNS Record

1. In AWX UI, go to **Templates** → `Cloudflare - Automation`
2. Click **Launch**
3. Fill in survey (dropdowns show live Cloudflare data)
4. Execute job
5. View results

### Verify in Cloudflare

1. Go to Cloudflare dashboard
2. Select your domain
3. Go to DNS records
4. You should see your new `test-awx` record! 

---

## What's Next?

### Explore More Operations

- **Update Record**: Change existing DNS records
- **Delete Record**: Remove DNS records
- **Different Types**: Try CNAME, TXT, MX records
- **Multiple Zones**: Manage different domains

### Production Enhancements

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for:
- Setting up Ingress for external access
- Configuring TLS/SSL
- High availability setup
- Backup strategies
- Monitoring & alerting

### Customize Surveys

Edit `playbooks/cloudflare/survey_spec.json.j2` to:
- Add new fields
- Change dropdown options
- Modify validations
- Add more operations

Then reapply:
```bash
make apply-survey
```

---

## Troubleshooting

### Can't Access AWX UI?

```bash
# Check port-forward is running
ps aux | grep port-forward

# Restart it
make port-forward
```

### Jobs Failing?

```bash
# Check Cloudflare token in secret
kubectl get secret cloudflare-credentials -n awx -o yaml

# Check task pod logs
kubectl logs -n awx -l app.kubernetes.io/component=task --tail=100
```

### Survey Not Showing Data?

```bash
# Re-run dropdown update
make update-dropdowns CLOUDFLARE_API_TOKEN=your_token

# Verify in AWX UI:
# Templates → Cloudflare - Automation → Survey tab
```

### Need More Help?

- **Full Documentation**: [README.md](README.md)
- **Detailed Deployment**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **All Make Commands**: Run `make help`

---

## Summary of Make Commands

```bash
# Installation
make install-all CLOUDFLARE_API_TOKEN=xxx    # Complete installation
make install-operator                         # Install operator only
make deploy-awx                               # Deploy AWX only
make create-secret CLOUDFLARE_API_TOKEN=xxx  # Create secret only

# Access
make get-password                             # Get admin password
make port-forward                             # Access AWX UI

# Configuration
make apply-survey                             # Apply survey config
make update-dropdowns CLOUDFLARE_API_TOKEN=xxx  # Update dropdown data
make verify-survey                            # Verify survey setup

# Maintenance
make check-awx                                # Check AWX status
make clean                                    # Clean up local images

# Image Building (optional)
make build-image                              # Build custom image
make push-image                               # Push to registry
make login-registry                           # Login to registry

# Help
make help                                     # Show all commands
```

---

## Architecture At-a-Glance

```
┌──────────────┐
│   You        │
│   Browser    │
└──────┬───────┘
       │ http://localhost:8052
       ▼
┌─────────────────────────────────┐
│   Kubernetes Cluster            │
│                                 │
│   ┌─────────────────────┐      │
│   │  AWX Web + Task     │      │
│   │  (Patched Image)    │      │
│   └──────────┬──────────┘      │
│              │                  │
│   ┌──────────▼──────────┐      │
│   │  PostgreSQL + Redis │      │
│   └─────────────────────┘      │
└─────────────┬───────────────────┘
              │ HTTPS API
              ▼
┌─────────────────────────┐
│   Cloudflare API        │
│   (Your DNS Records)    │
└─────────────────────────┘
```

---

## Tips & Best Practices

- **Always test with non-production domains first**
- **Use manual entry when creating new records**
- **Update dropdowns after making changes outside AWX**
- **Keep your Cloudflare token secure** (use Kubernetes secrets)
- **Check job output** if something doesn't work as expected
- **Use TTL "auto"** unless you need specific caching behavior

---

## Congratulations

You now have a fully functional AWX Cloudflare automation system!

Manage DNS records with a beautiful web interface instead of CLI or API calls.

Happy Automating!
