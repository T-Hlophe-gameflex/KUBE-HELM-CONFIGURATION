# AWX Cloudflare Automation - Deployment Guide

**Complete step-by-step guide for deploying AWX with Cloudflare automation to any Kubernetes cluster.**

---

## 📑 Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Architecture Overview](#architecture-overview)
- [Deployment Steps](#deployment-steps)
  - [Phase 1: Environment Preparation](#phase-1-environment-preparation)
  - [Phase 2: AWX Operator Installation](#phase-2-awx-operator-installation)
  - [Phase 3: AWX Instance Deployment](#phase-3-awx-instance-deployment)
  - [Phase 4: Cloudflare Configuration](#phase-4-cloudflare-configuration)
  - [Phase 5: Template & Survey Setup](#phase-5-template--survey-setup)
- [Post-Deployment Validation](#post-deployment-validation)
- [Production Considerations](#production-considerations)
- [Upgrade Procedures](#upgrade-procedures)
- [Rollback Procedures](#rollback-procedures)

---

## Pre-Deployment Checklist

### Kubernetes Cluster Requirements

- [ ] **Cluster Version**: Kubernetes v1.24 or higher
- [ ] **kubectl Access**: Configured and tested (`kubectl cluster-info`)
- [ ] **Cluster Resources**:
  - [ ] 4+ CPU cores available
  - [ ] 8+ GB RAM available
  - [ ] 20+ GB storage for persistent volumes
- [ ] **StorageClass**: Default or specified storageClass configured
- [ ] **Network Policies**: Allowing egress to Cloudflare API (api.cloudflare.com:443)

### Cloudflare Setup

- [ ] **Cloudflare Account**: Active account with at least one zone
- [ ] **API Token Created**: With required permissions
  - [ ] Zone - Zone - Read
  - [ ] Zone - DNS - Edit
  - [ ] Zone - Zone Settings - Edit
- [ ] **API Token Tested**: Verified with curl/API call

### Local Environment

- [ ] **Docker Installed**: For building custom images (optional)
- [ ] **kubectl Installed**: Version compatible with cluster
- [ ] **make Installed**: For running automated commands
- [ ] **curl/wget**: For API testing
- [ ] **jq**: For JSON processing (optional but helpful)

### Files Prepared

- [ ] **CF_AWX_AUTO Package**: Extracted/cloned to local machine
- [ ] **config/awx-instance.yaml**: Created and customized
- [ ] **config/.env**: Created from .env.example with your values

---

## Architecture Overview

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              awx-system namespace                    │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │      AWX Operator Deployment                │   │   │
│  │  │  - Manages AWX CR lifecycle                 │   │   │
│  │  │  - Handles upgrades & patches               │   │   │
│  │  │  - Reconciles desired state                 │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                            ↓                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                awx namespace                         │   │
│  │                                                       │   │
│  │  ┌───────────────────────────────────────────────┐ │   │
│  │  │        AWX Custom Resource (CR)               │ │   │
│  │  │  - Defines AWX instance configuration         │ │   │
│  │  │  - Specifies images, resources, storage       │ │   │
│  │  └───────────────────────────────────────────────┘ │   │
│  │                            ↓                         │   │
│  │  ┌───────────────────────────────────────────────┐ │   │
│  │  │     AWX Deployment (Web + Task)               │ │   │
│  │  │                                                │ │   │
│  │  │  ┌────────────────────────────────────────┐  │ │   │
│  │  │  │  Web Pod (UI + API)                   │  │ │   │
│  │  │  │  Image: awx-cloudflare-auto:24.6.1    │  │ │   │
│  │  │  │  - Serves AWX web interface            │  │ │   │
│  │  │  │  - REST API endpoints                  │  │ │   │
│  │  │  │  - Patched inventory dump              │  │ │   │
│  │  │  └────────────────────────────────────────┘  │ │   │
│  │  │                                                │ │   │
│  │  │  ┌────────────────────────────────────────┐  │ │   │
│  │  │  │  Task Pod (Job Executor)              │  │ │   │
│  │  │  │  Image: awx-cloudflare-auto:24.6.1    │  │ │   │
│  │  │  │  - Runs Ansible playbooks              │  │ │   │
│  │  │  │  - Executes Cloudflare automation      │  │ │   │
│  │  │  │  - Manages job queue                   │  │ │   │
│  │  │  └────────────────────────────────────────┘  │ │   │
│  │  └───────────────────────────────────────────────┘ │   │
│  │                            ↓                         │   │
│  │  ┌───────────────────────────────────────────────┐ │   │
│  │  │       PostgreSQL StatefulSet                  │ │   │
│  │  │  - AWX database                               │ │   │
│  │  │  - Job history & config                       │ │   │
│  │  │  - Persistent Volume (8Gi)                    │ │   │
│  │  └───────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  │  ┌───────────────────────────────────────────────┐ │   │
│  │  │         Redis Deployment                      │ │   │
│  │  │  - Cache layer                                │ │   │
│  │  │  - Message broker for Celery                  │ │   │
│  │  └───────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  │  ┌───────────────────────────────────────────────┐ │   │
│  │  │         Kubernetes Secrets                    │ │   │
│  │  │  - cloudflare-credentials (API token)        │ │   │
│  │  │  - awx-admin-password (auto-generated)       │ │   │
│  │  │  - postgres password (auto-generated)        │ │   │
│  │  └───────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  │  ┌───────────────────────────────────────────────┐ │   │
│  │  │         Services                              │ │   │
│  │  │  - awx-service (ClusterIP:80)                 │ │   │
│  │  │  - postgres-service (ClusterIP:5432)          │ │   │
│  │  │  - redis-service (ClusterIP:6379)             │ │   │
│  │  └───────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                              ↓ HTTPS API Calls
                    ┌──────────────────────┐
                    │   Cloudflare API     │
                    │  api.cloudflare.com  │
                    │  - DNS Management    │
                    │  - Zone Settings     │
                    └──────────────────────┘
```

### Data Flow

1. **User** → AWX Web UI (port-forward or ingress)
2. **AWX Web** → Survey form presented to user
3. **User** → Fills survey and launches job
4. **AWX Task Pod** → Retrieves Cloudflare token from secret
5. **AWX Task Pod** → Executes Ansible playbook
6. **Playbook** → Calls Cloudflare API
7. **Cloudflare** → Makes requested changes
8. **Results** → Stored in PostgreSQL
9. **AWX Web** → Displays job results to user

---

## Deployment Steps

### Phase 1: Environment Preparation

#### 1.1 Extract Package
```bash
# Navigate to extraction directory
cd /path/to/CF_AWX_AUTO

# Verify contents
ls -la
# Should see: Makefile, README.md, playbooks/, awx-image/, scripts/, config/, docs/
```

#### 1.2 Configure Environment Variables
```bash
# Copy environment template
cp config/.env.example config/.env

# Edit with your values
nano config/.env  # or vim, code, etc.

# Minimum required variables:
# - CLOUDFLARE_API_TOKEN
# - REGISTRY_USER (if building custom image)
```

#### 1.3 Test Cloudflare API Token
```bash
# Verify token works
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json"

# Expected response:
# {"result":{"id":"...","status":"active"},"success":true,...}
```

#### 1.4 Verify Kubernetes Access
```bash
# Check cluster connection
kubectl cluster-info

# Check available resources
kubectl top nodes

# Verify you can create resources
kubectl auth can-i create namespace
```

#### 1.5 Create AWX Instance Configuration
```bash
# Create config file
cat > config/awx-instance.yaml <<EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ansible-awx
  namespace: awx
spec:
  # Service configuration
  service_type: ClusterIP
  ingress_type: none
  
  # Image configuration
  image: docker.io/blackthami/awx-cloudflare-auto
  image_version: 24.6.1-cf-auto
  image_pull_policy: IfNotPresent
  
  # Web pod resources
  web_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  # Task pod resources
  task_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  # PostgreSQL configuration
  postgres_resource_requirements:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
  
  postgres_storage_class: standard
  postgres_storage_requirements:
    requests:
      storage: 8Gi
  
  # Execution environment
  ee_images:
    - name: AWX EE
      image: quay.io/ansible/awx-ee:24.6.1
EOF

# For production, consider adding ingress configuration:
#   ingress_type: ingress
#   ingress_hosts:
#     - hostname: awx.yourdomain.com
#       tls_secret: awx-tls
```

---

### Phase 2: AWX Operator Installation

#### 2.1 Install AWX Operator
```bash
# Using Makefile (recommended)
make install-operator

# Or manually:
kubectl create namespace awx || true
kubectl apply -k https://github.com/ansible/awx-operator/config/default?ref=2.19.1
```

#### 2.2 Verify Operator Installation
```bash
# Check operator deployment
kubectl get deployment -n awx-system
# Expected: awx-operator-controller-manager with 1/1 READY

# Check operator logs
kubectl logs -n awx-system deployment/awx-operator-controller-manager --tail=50

# Wait for operator to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/awx-operator-controller-manager -n awx-system
```

#### 2.3 Verify CRD Installation
```bash
# Check AWX CRD
kubectl get crd awxs.awx.ansible.com

# Expected output showing CRD created
```

---

### Phase 3: AWX Instance Deployment

#### 3.1 Create Namespace
```bash
# Create AWX namespace
kubectl create namespace awx

# Verify namespace
kubectl get namespace awx
```

#### 3.2 Create Cloudflare Secret
```bash
# Using Makefile (recommended)
make create-secret CLOUDFLARE_API_TOKEN=your_token_here

# Or manually:
kubectl create secret generic cloudflare-credentials \
  --from-literal=token=your_token_here \
  -n awx

# Verify secret
kubectl get secret cloudflare-credentials -n awx
```

#### 3.3 Deploy AWX Instance
```bash
# Deploy using configuration file
kubectl apply -f config/awx-instance.yaml

# Verify AWX resource created
kubectl get awx -n awx

# Expected output:
# NAME           AGE
# ansible-awx    10s
```

#### 3.4 Monitor Deployment Progress
```bash
# Watch AWX status
kubectl get awx -n awx -w

# Check operator logs for progress
kubectl logs -n awx-system deployment/awx-operator-controller-manager -f

# Wait for deployment to complete (5-10 minutes)
kubectl wait --for=condition=Progressing=False awx/ansible-awx -n awx --timeout=600s
```

#### 3.5 Verify All Pods Running
```bash
# Check all pods
kubectl get pods -n awx

# Expected pods:
# - ansible-awx-postgres-15-0 (1/1 Running)
# - ansible-awx-task-xxxxx (4/4 Running)
# - ansible-awx-web-xxxxx (3/3 Running)

# If any pods are not ready, check logs:
kubectl logs -n awx <pod-name> -c <container-name>
```

#### 3.6 Get Admin Password
```bash
# Using Makefile
make get-password

# Or manually:
kubectl get secret ansible-awx-admin-password -n awx \
  -o jsonpath="{.data.password}" | base64 --decode && echo

# Save this password - you'll need it to login!
```

---

### Phase 4: Cloudflare Configuration

#### 4.1 Access AWX UI
```bash
# Start port-forward in background
make port-forward &

# Or in separate terminal:
kubectl port-forward -n awx svc/ansible-awx-service 8052:80

# Open browser: http://localhost:8052
# Username: admin
# Password: (from step 3.6)
```

#### 4.2 Create Project in AWX UI

1. **Login** to AWX UI
2. **Navigate** to Resources → Projects
3. **Click** "Add" button
4. **Fill in**:
   - Name: `Cloudflare Automation`
   - Organization: `Default`
   - Source Control Type: `Manual`
   - (Or use Git if you've pushed playbooks to a repo)
5. **Click** "Save"

#### 4.3 Upload Playbooks

**Option A: Manual Upload**
```bash
# Copy playbooks into AWX project directory
kubectl cp playbooks/cloudflare ansible-awx-task-xxxxx:/var/lib/awx/projects/cloudflare_automation/ -n awx

# Or exec into pod and create files
kubectl exec -it -n awx ansible-awx-task-xxxxx -- bash
mkdir -p /var/lib/awx/projects/cloudflare_automation
# Then copy files manually
```

**Option B: Git Repository (Recommended for production)**
```bash
# Push playbooks to your Git repository
git init
git add playbooks/
git commit -m "Add Cloudflare playbooks"
git remote add origin https://github.com/yourusername/cloudflare-awx.git
git push -u origin main

# Then in AWX UI:
# - Set Project SCM Type to "Git"
# - Set SCM URL to your repository
# - Click "Save" and "Sync" button
```

#### 4.4 Create Inventory

1. **Navigate** to Resources → Inventories
2. **Click** "Add" → "Add inventory"
3. **Fill in**:
   - Name: `Localhost`
   - Organization: `Default`
4. **Click** "Save"
5. **Go to** Hosts tab → Click "Add"
6. **Fill in**:
   - Name: `localhost`
   - Variables:
     ```yaml
     ---
     ansible_connection: local
     ansible_python_interpreter: /usr/bin/python3
     ```
7. **Click** "Save"

#### 4.5 Create Cloudflare Credential

1. **Navigate** to Resources → Credentials
2. **Click** "Add"
3. **Fill in**:
   - Name: `Cloudflare API Token`
   - Credential Type: `Custom`
   - Injector Configuration:
     ```yaml
     ---
     env:
       CLOUDFLARE_API_TOKEN: "{{ cloudflare_token }}"
     ```
   - Credential Fields:
     ```json
     {
       "fields": [
         {
           "id": "cloudflare_token",
           "label": "Cloudflare API Token",
           "type": "string",
           "secret": true
         }
       ]
     }
     ```
4. **Enter** your Cloudflare API token in the `cloudflare_token` field
5. **Click** "Save"

---

### Phase 5: Template & Survey Setup

#### 5.1 Create Job Template Manually

1. **Navigate** to Resources → Templates
2. **Click** "Add" → "Add job template"
3. **Fill in**:
   - Name: `Cloudflare - Automation`
   - Job Type: `Run`
   - Inventory: `Localhost`
   - Project: `Cloudflare Automation`
   - Playbook: `cloudflare_awx_playbook.yml`
   - Credentials: `Cloudflare API Token`
   - Variables:
     ```yaml
     ---
     cloudflare_api_token: "{{ lookup('env', 'CLOUDFLARE_API_TOKEN') }}"
     ```
   - Options:
     - ☑ Prompt on launch
     - ☑ Enable webhook
4. **Click** "Save"
5. **Note the Template ID** (visible in URL or template list)

#### 5.2 Apply Survey Configuration
```bash
# Update scripts with your template ID
# Edit scripts/awx_survey_manager.sh if needed

# Apply survey using Makefile
make apply-survey

# Or use script directly:
./scripts/awx_survey_manager.sh apply-survey \
  --template-id 21 \
  --host localhost:8052
```

#### 5.3 Verify Survey Applied
```bash
# Check survey in AWX UI
# Navigate to Template → Survey tab
# Should see 13 survey questions

# Or verify via script:
make verify-survey
```

#### 5.4 Populate Dropdowns with Cloudflare Data
```bash
# Update dropdowns with live data
make update-dropdowns CLOUDFLARE_API_TOKEN=your_token

# Or manually:
CLOUDFLARE_API_TOKEN=your_token \
  ./scripts/awx_survey_manager.sh update-dropdowns \
  --template-id 21 \
  --host localhost:8052
```

#### 5.5 Verify Dropdown Population

1. **Navigate** to Template → Survey tab
2. **Check** these fields have your data:
   - `existing_domain`: Should show your Cloudflare zones
   - `existing_record`: Should show your DNS records
   - `record_type`: Should show DNS types (A, AAAA, CNAME, etc.)
3. **Verify** no placeholder values like `[MANUAL_ENTRY]` or `[NONE]`

---

## Post-Deployment Validation

### Validation Checklist

#### AWX System Health

```bash
# 1. Check all pods running
kubectl get pods -n awx
# All pods should show "Running" with all containers ready

# 2. Check AWX instance status
kubectl get awx -n awx
# Should show Progressing: False (deployment complete)

# 3. Check operator logs for errors
kubectl logs -n awx-system deployment/awx-operator-controller-manager --tail=100 | grep -i error

# 4. Verify services
kubectl get svc -n awx
# Should see: ansible-awx-service, ansible-awx-postgres-15, ansible-awx-redis

# 5. Check persistent volumes
kubectl get pvc -n awx
# Should see bound PVC for PostgreSQL
```

#### AWX UI Access

```bash
# 1. Verify port-forward working
curl -I http://localhost:8052

# 2. Login to UI
# Open browser: http://localhost:8052
# Username: admin
# Password: (from get-password)

# 3. Check Dashboard
# Should show:
# - Hosts: 1 (localhost)
# - Inventories: 1+
# - Projects: 1+
# - Templates: 1+ (Cloudflare template)
```

#### Cloudflare Integration

```bash
# 1. Test API connection from AWX pod
kubectl exec -it -n awx ansible-awx-task-xxxxx -- bash
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# 2. Verify secret mounted
kubectl exec -it -n awx ansible-awx-task-xxxxx -- env | grep CLOUDFLARE

# 3. Check playbooks loaded
kubectl exec -it -n awx ansible-awx-task-xxxxx -- \
  ls -la /var/lib/awx/projects/
```

#### Template & Survey Validation

**Via UI:**
1. Navigate to Templates → "Cloudflare - Automation"
2. Click "Launch"
3. Verify survey shows:
   - Operation dropdown (create, update, delete)
   - Domain dropdown with your zones
   - Record dropdown with your records
   - Record type dropdown (A, AAAA, CNAME, etc.)
   - All fields properly labeled
   - No placeholder values

**Via Script:**
```bash
make verify-survey
```

#### Test Job Execution

**Test 1: View Existing Records (Safe)**
```bash
# Launch job with these survey values:
# - Operation: update (but don't actually change anything)
# - Existing Record: <select any>
# - Keep all other values same
# Click Launch

# Job should:
# - Start successfully
# - Connect to Cloudflare API
# - Show record details
# - Complete without errors
```

**Test 2: Create Test Record**
```bash
# Launch job with:
# - Operation: create
# - Domain: <your test domain>
# - Record Type: TXT
# - Record Name: awx-test
# - Target/Content: "AWX Deployment Test"
# - TTL: auto
# - Proxied: false
# Click Launch

# Verify in Cloudflare dashboard
# Then delete test record
```

---

## Production Considerations

### Security Hardening

#### 1. Use Ingress with TLS
```yaml
# Update config/awx-instance.yaml
spec:
  ingress_type: ingress
  ingress_tls_secret: awx-tls-secret
  ingress_hosts:
    - hostname: awx.yourdomain.com
      tls_secret: awx-tls-secret
```

#### 2. Network Policies
```yaml
# Create network policy to restrict AWX pod access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: awx-netpol
  namespace: awx
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: awx
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
  - to:
    - podSelector: {}
  - ports:
    - protocol: TCP
      port: 443
    to:
    - podSelector: {}
```

#### 3. RBAC Configuration
```bash
# Create service account with minimal permissions
kubectl create serviceaccount awx-job-runner -n awx

# Create role with only necessary permissions
# Bind role to service account
# Update AWX to use service account
```

#### 4. Secret Management
```bash
# Use external secret management
# Examples:
# - HashiCorp Vault
# - AWS Secrets Manager
# - Azure Key Vault
# - Google Secret Manager

# Install external-secrets operator
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
```

### High Availability

#### 1. Multiple Replicas
```yaml
# Update config/awx-instance.yaml
spec:
  replicas: 3  # Multiple web pods
  task_replicas: 3  # Multiple task pods
```

#### 2. External PostgreSQL
```yaml
spec:
  postgres_configuration_secret: external-postgres-config
  # Don't create internal postgres
```

#### 3. External Redis
```yaml
spec:
  redis_configuration_secret: external-redis-config
```

### Backup Strategy

#### 1. PostgreSQL Backups
```bash
# Create CronJob for automated backups
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: awx-postgres-backup
  namespace: awx
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h ansible-awx-postgres-15 -U awx awx > /backup/awx-\$(date +%Y%m%d-%H%M%S).sql
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: awx-backup-pvc
          restartPolicy: OnFailure
EOF
```

#### 2. AWX Configuration Backup
```bash
# Backup AWX objects (templates, inventories, etc.)
awx-cli export --all > awx-backup-$(date +%Y%m%d).json
```

### Monitoring & Alerting

#### 1. Enable Prometheus Metrics
```yaml
# Update AWX instance
spec:
  metrics_utility_enabled: true
  metrics_utility_image_pull_policy: IfNotPresent
```

#### 2. Install Prometheus ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: awx-metrics
  namespace: awx
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: awx
  endpoints:
  - port: metrics
    interval: 30s
```

#### 3. Setup Alerts
```yaml
# Example Prometheus alert rules
groups:
- name: awx
  rules:
  - alert: AWXPodDown
    expr: up{job="awx"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "AWX pod is down"
  
  - alert: AWXJobFailureRate
    expr: rate(awx_job_failures_total[5m]) > 0.1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High job failure rate"
```

---

## Upgrade Procedures

### Upgrading AWX

#### 1. Check Current Version
```bash
kubectl get awx -n awx -o jsonpath='{.items[0].status.version}'
```

#### 2. Backup Before Upgrade
```bash
# Backup database
kubectl exec -it -n awx ansible-awx-postgres-15-0 -- \
  pg_dump -U awx awx > awx-backup-before-upgrade.sql

# Backup AWX config
awx-cli export --all > awx-config-backup.json
```

#### 3. Upgrade AWX Operator
```bash
# Update operator to newer version
kubectl apply -k https://github.com/ansible/awx-operator/config/default?ref=2.20.0
```

#### 4. Upgrade AWX Instance
```bash
# Update image version in config/awx-instance.yaml
spec:
  image_version: 24.7.0-cf-auto  # New version

# Apply changes
kubectl apply -f config/awx-instance.yaml

# Monitor upgrade
kubectl get awx -n awx -w
```

### Upgrading Cloudflare Playbooks

```bash
# 1. Test new playbooks locally first
# 2. Update playbooks in project directory
# 3. Sync project in AWX UI
# 4. Test with non-production data
# 5. Roll out to production
```

---

## Rollback Procedures

### Rollback AWX Instance

#### 1. Identify Previous Version
```bash
# Check deployment history
kubectl rollout history deployment/ansible-awx-web -n awx
```

#### 2. Rollback Deployment
```bash
# Revert to previous version
kubectl rollout undo deployment/ansible-awx-web -n awx
kubectl rollout undo deployment/ansible-awx-task -n awx

# Or rollback to specific revision
kubectl rollout undo deployment/ansible-awx-web -n awx --to-revision=2
```

#### 3. Restore Database (if needed)
```bash
# Copy backup to pod
kubectl cp awx-backup.sql ansible-awx-postgres-15-0:/tmp/ -n awx

# Restore
kubectl exec -it -n awx ansible-awx-postgres-15-0 -- \
  psql -U awx -d awx -f /tmp/awx-backup.sql
```

#### 4. Verify Rollback
```bash
# Check version
kubectl get awx -n awx -o jsonpath='{.items[0].status.version}'

# Test functionality
# Login to UI and run test job
```

---

## Support & Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

Common issues:
- Pods not starting → Check resources and images
- Can't access UI → Verify port-forward and services
- Jobs failing → Check Cloudflare token and playbooks
- Survey not updating → Re-run update-dropdowns

---

## Deployment Complete

Your AWX Cloudflare automation is now ready for production use.
