# AWX Cloudflare Automation 

**A production-ready, plug-and-play Ansible AWX implementation for managing Cloudflare DNS, rules, and configurations through an intuitive web interface.**

This distribution package provides everything needed to deploy AWX with Cloudflare automation capabilities to any Kubernetes cluster. It includes a patched AWX image, pre-configured job templates, dynamic survey forms populated with live Cloudflare data, and automation scripts for seamless setup.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Features

### AWX Enhancements
- **Patched AWX Image**: Includes fix for inventory dump functionality
- **Pre-configured Templates**: Ready-to-use Cloudflare automation job templates
- **Dynamic Surveys**: Survey dropdowns automatically populated with live Cloudflare data
- **No Manual Entry**: Clean interface with only actual Cloudflare zones and records

### Cloudflare Operations
- **DNS Management**: Create, update, and delete DNS records (A, AAAA, CNAME, TXT, MX, etc.)
- **Record Types**: Support for all major DNS record types
- **Zone Management**: Multi-zone support with dynamic zone selection
- **Validation**: Built-in validation for record names and configurations
- **TTL Control**: Flexible TTL management (auto or custom)
- **Proxying**: Toggle Cloudflare proxy status per record

### Automation & DevOps
- **Makefile Automation**: One-command installation and configuration
- **Kubernetes Native**: Deploys using AWX Operator for Kubernetes
- **Portable**: Works on any Kubernetes cluster (on-prem, cloud, local)
- **Secrets Management**: Kubernetes-native secret handling
- **Survey Management**: Unified script for survey operations

---

## Prerequisites

### Required Tools
- **Kubernetes Cluster**: v1.24+ (can be minikube, kind, k3s, GKE, EKS, AKS, etc.)
- **kubectl**: Configured to access your cluster
- **Docker**: For building the patched AWX image (optional if using pre-built image)
- **make**: For running automated setup commands
- **bash**: For running management scripts

### Kubernetes Resources (Minimum)
- **CPU**: 4 cores
- **Memory**: 8GB RAM
- **Storage**: 20GB persistent volume support

### Cloudflare Requirements
- **Cloudflare Account**: Free or paid tier
- **API Token**: With permissions:
  - Zone - Zone - Read
  - Zone - DNS - Edit
  - Zone - Zone Settings - Edit

### Network Access
- Cluster must reach:
  - `quay.io` (for AWX Operator images)
  - `docker.io` (for patched AWX image)
  - `api.cloudflare.com` (for API calls)

---

## Quick Start

### 1. Clone or Extract This Package
```bash
cd CF_AWX_AUTO
```

### 2. Create Cloudflare API Token
Visit: https://dash.cloudflare.com/profile/api-tokens

Create token with these permissions:
- Zone - Zone - Read
- Zone - DNS - Edit  
- Zone - Zone Settings - Edit

### 3. Create AWX Instance Configuration
```bash
cat > config/awx-instance.yaml <<EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ansible-awx
spec:
  service_type: ClusterIP
  ingress_type: none
  
  # Use the patched AWX image
  image: docker.io/blackthami/awx-cloudflare-auto
  image_version: 24.6.1-cf-auto
  
  # Resource requests
  web_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  task_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  
  # PostgreSQL settings
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
EOF
```

### 4. Install Everything
```bash
# Complete installation with one command
make install-all CLOUDFLARE_API_TOKEN=your_cloudflare_token_here
```

This will:
- Install AWX Operator
- Create Cloudflare credentials secret
- Deploy AWX instance
- Wait for AWX to be ready

### 5. Access AWX
```bash
# Get admin password
make get-password

# Start port-forward (in another terminal or background)
make port-forward &

# Open browser to http://localhost:8052
# Login: admin / (password from above)
```

### 6. Configure Cloudflare Template
```bash
# Create job template and apply survey
make configure-template
make apply-survey

# Populate dropdowns with your Cloudflare zones and records
make update-dropdowns CLOUDFLARE_API_TOKEN=your_cloudflare_token_here
```

### 7. Start Managing Cloudflare
Navigate to Templates → "Cloudflare - Automation" → Launch

---

## Detailed Installation

### Step-by-Step Process

#### 1. Prepare Your Environment
```bash
# Verify kubectl access
kubectl cluster-info

# Create namespace
kubectl create namespace awx

# Verify you can pull images
docker pull quay.io/ansible/awx-operator:2.19.1
```

#### 2. (Optional) Build Custom Image
If you want to build your own patched image:

```bash
# Build image
make build-image REGISTRY_USER=yourusername IMAGE_TAG=custom-tag

# Login to registry
make login-registry

# Push image
make push-image

# Update config/awx-instance.yaml with your image
```

#### 3. Install AWX Operator
```bash
make install-operator

# Verify operator is running
kubectl get deployment -n awx-system
```

#### 4. Create Secrets
```bash
# Cloudflare API token
make create-secret CLOUDFLARE_API_TOKEN=your_token

# Verify secret
kubectl get secret cloudflare-credentials -n awx
```

#### 5. Deploy AWX Instance
```bash
# Deploy (uses config/awx-instance.yaml)
make deploy-awx

# Watch deployment progress
kubectl get awx -n awx -w

# Check pods
kubectl get pods -n awx
```

#### 6. Access AWX UI
```bash
# Get admin password
PASSWORD=$(make get-password)
echo $PASSWORD

# Port-forward to access UI
make port-forward

# In browser: http://localhost:8052
# Username: admin
# Password: (from above)
```

#### 7. Configure Job Template

##### a. Import Playbook to AWX
In AWX UI:
1. Go to **Projects** → Create new project
2. Name: "Cloudflare Automation"
3. SCM Type: Manual (or Git if you have a repo)
4. Playbook Directory: Copy `playbooks/cloudflare/` to AWX project path

##### b. Create Job Template
```bash
# Use the survey manager to configure template
./scripts/awx_survey_manager.sh update-template \
  --template-id 21 \
  --host localhost:8052

# Apply survey configuration  
make apply-survey
```

##### c. Populate Survey Dropdowns
```bash
# Fetch live Cloudflare data and update dropdowns
make update-dropdowns CLOUDFLARE_API_TOKEN=your_token

# Verify survey configuration
make verify-survey
```

---

## Configuration

### Environment Variables

Create a `.env` file (see `.env.example`):

```bash
# Cloudflare Configuration
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here

# AWX Configuration  
AWX_HOST=localhost:8052
AWX_ADMIN_USER=admin
AWX_TEMPLATE_ID=21
KUBE_NAMESPACE=awx
AWX_INSTANCE_NAME=ansible-awx

# Image Configuration (for custom builds)
REGISTRY=docker.io
REGISTRY_USER=yourusername
IMAGE_NAME=awx-cloudflare-auto
IMAGE_TAG=24.6.1-cf-auto
```

### Customizing AWX Instance

Edit `config/awx-instance.yaml`:

```yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ansible-awx
spec:
  # Use LoadBalancer for cloud environments
  service_type: LoadBalancer  # or ClusterIP, NodePort
  
  # Enable ingress for production
  ingress_type: ingress
  ingress_hosts:
    - hostname: awx.yourdomain.com
  
  # Custom image
  image: your-registry/awx-cloudflare-auto
  image_version: your-tag
  
  # Scale resources based on needs
  web_resource_requirements:
    requests:
      cpu: 1000m
      memory: 2Gi
  
  # Custom PostgreSQL configuration
  postgres_storage_class: fast-ssd
  postgres_storage_requirements:
    requests:
      storage: 20Gi
```

### Survey Customization

Edit `playbooks/cloudflare/survey_spec.json.j2` to customize survey fields:

```json
{
  "name": "operation",
  "question_name": "Operation",
  "choices": ["create", "update", "delete"],
  "default": "create",
  "type": "multiplechoice"
}
```

Then reapply:
```bash
make apply-survey
```

---

## Usage

### Managing DNS Records

#### Create a New DNS Record
1. Navigate to **Templates** → "Cloudflare - Automation"
2. Click **Launch** 
3. Fill in survey:
   - Operation: `create`
   - Domain: Select from dropdown
   - Record Type: `A`
   - Record Name: `api` (for api.yourdomain.com)
   - Target: `192.168.1.100`
   - TTL: `auto` or custom seconds
   - Proxied: `true` for Cloudflare proxy
4. Click **Launch**

#### Update Existing Record
1. Launch template
2. Survey:
   - Operation: `update`
   - Existing Record: Select from dropdown
   - New Target: `192.168.1.200`
   - Click **Launch**

#### Delete Record
1. Launch template
2. Survey:
   - Operation: `delete`
   - Existing Record: Select from dropdown
   - Confirm: `yes`
3. Click **Launch**

### Using Manual Entry
If you need to create records not in dropdowns:
1. Leave "Existing Record" empty
2. Fill in "Manual Record Name"
3. Manual entry takes priority

### Refreshing Dropdowns
When you add zones/records outside AWX:
```bash
make update-dropdowns CLOUDFLARE_API_TOKEN=your_token
```

---

## Architecture

### Components

```
┌─────────────────────────────────────────┐
│          Kubernetes Cluster             │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐ │
│  │       AWX Operator (awx-system)   │ │
│  │  - Manages AWX lifecycle          │ │
│  │  - Handles updates/upgrades       │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │         AWX Instance (awx)        │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │   Web Pod (patched image)   │ │ │
│  │  │  - AWX UI                   │ │ │
│  │  │  - REST API                 │ │ │
│  │  │  - Inventory dump fix       │ │ │
│  │  └─────────────────────────────┘ │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │  Task Pod (patched image)   │ │ │
│  │  │  - Job execution            │ │ │
│  │  │  - Cloudflare playbooks     │ │ │
│  │  └─────────────────────────────┘ │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │      PostgreSQL Pod         │ │ │
│  │  │  - AWX database             │ │ │
│  │  │  - Persistent storage       │ │ │
│  │  └─────────────────────────────┘ │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │        Redis Pod            │ │ │
│  │  │  - Cache & message queue    │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   Secrets                         │ │
│  │  - cloudflare-credentials        │ │
│  │  - awx-admin-password            │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
          │
          │ API Calls
          ▼
┌─────────────────────────────────────────┐
│       Cloudflare API                    │
│  - DNS Management                       │
│  - Zone Configuration                   │
│  - Rules & Settings                     │
└─────────────────────────────────────────┘
```

### Data Flow

1. **User** launches job template via AWX UI
2. **Survey** validates and collects input
3. **AWX Task Pod** executes Ansible playbook
4. **Playbook** calls Cloudflare API with token from secret
5. **Cloudflare** applies changes to DNS/zones
6. **Results** displayed in AWX UI

### File Structure
```
CF_AWX_AUTO/
├── Makefile              # Automation commands
├── README.md             # This file
├── awx-image/
│   ├── Dockerfile        # Patched AWX image
│   ├── jobs.py           # Inventory dump fix
│   └── README.md
├── config/
│   ├── awx-instance.yaml # AWX deployment config
│   └── .env.example      # Environment template
├── docs/
│   ├── DEPLOYMENT.md     # Detailed deployment guide
│   └── TROUBLESHOOTING.md
├── playbooks/
│   └── cloudflare/
│       ├── cloudflare_awx_playbook.yml  # Main playbook
│       ├── survey_spec.json.j2          # Survey template
│       ├── cloudflare_modern_rules.j2   # Rules template
│       └── tasks/
│           ├── resolve_variables.yml    # Variable resolution
│           ├── prepare_record_variables.yml  # Record prep
│           ├── manage_dns_record.yml    # DNS operations
│           └── ... (other tasks)
└── scripts/
    └── awx_survey_manager.sh  # Survey management utility
```

---

## Troubleshooting

### Common Issues

#### AWX Operator Not Starting
```bash
# Check operator logs
kubectl logs -n awx-system deployment/awx-operator-controller-manager

# Verify RBAC permissions
kubectl auth can-i create awx --as=system:serviceaccount:awx-system:awx-operator-controller-manager
```

#### AWX Pods Not Running
```bash
# Check AWX instance status
kubectl describe awx ansible-awx -n awx

# Check pod events
kubectl get events -n awx --sort-by='.lastTimestamp'

# Check specific pod
kubectl describe pod ansible-awx-web-xxxxx -n awx
```

#### Survey Not Updating
```bash
# Verify API token is correct
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Re-apply survey
make apply-survey

# Force refresh dropdowns
make update-dropdowns CLOUDFLARE_API_TOKEN=your_token
```

#### Job Execution Failures
```bash
# Check job output in AWX UI
# Go to Jobs → Select failed job → View output

# Common fixes:
# 1. Verify Cloudflare secret exists
kubectl get secret cloudflare-credentials -n awx -o yaml

# 2. Check playbook syntax
ansible-playbook --syntax-check playbooks/cloudflare/cloudflare_awx_playbook.yml

# 3. Test Cloudflare API manually
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### Can't Access AWX UI
```bash
# Check port-forward is running
ps aux | grep "port-forward"

# Restart port-forward
make port-forward

# Alternative: Use kubectl directly
kubectl port-forward -n awx svc/ansible-awx-service 8052:80

# Check service exists
kubectl get svc -n awx
```

### Debug Mode

Enable verbose logging:

1. Edit survey to add `ansible_verbose` variable
2. Set value to `-vvv` for max verbosity
3. Check job output for detailed logs

### Getting Help

- **GitHub Issues**: [Project Issues](your-repo-url/issues)
- **AWX Documentation**: https://ansible.readthedocs.io/projects/awx/
- **Cloudflare API Docs**: https://developers.cloudflare.com/api/

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch
3. Make your changes
4. Test thoroughly
5. Submit pull request

### Development Setup
```bash
# Clone your fork
git clone your-fork-url
cd CF_AWX_AUTO

# Make changes to playbooks/scripts
# Test in local cluster (kind/minikube)

# Rebuild image if needed
make build-image IMAGE_TAG=dev

# Test installation
make install-all
```

---

## License

MIT License - see LICENSE file

---

## Acknowledgments

- **Ansible AWX Team**: For the excellent automation platform
- **Cloudflare**: For comprehensive API
- **Community**: For testing and feedback

---

## Support

Need help? Try these resources:

1. **Documentation**: Start with [DEPLOYMENT.md](docs/DEPLOYMENT.md)
2. **Troubleshooting**: Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. **Issues**: Search or create [GitHub issue](your-repo-url/issues)
4. **Discussions**: Join [Discussions](your-repo-url/discussions)

---

**Built for the DevOps community**

*Ship it anywhere, manage Cloudflare everywhere!*
