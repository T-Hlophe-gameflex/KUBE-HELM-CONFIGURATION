# CF_AWX_AUTO - Project Structure

Complete directory structure and file overview for the AWX Cloudflare Automation distribution package.

---

## 📁 Directory Tree

```
CF_AWX_AUTO/
├── Makefile                      # Main automation commands for installation & management
├── README.md                     # Complete documentation
├── QUICKSTART.md                 # 15-minute quick start guide
│
├── awx-image/                    # Patched AWX image building
│   ├── Dockerfile                # Builds AWX with inventory dump fix
│   ├── jobs.py                   # Patched jobs.py for inventory dump
│   └── README.md                 # Image building instructions
│
├── config/                       # Configuration files
│   ├── .env.example              # Environment variables template (195 lines)
│   └── awx-instance.yaml.example # AWX deployment configuration (347 lines)
│
├── docs/                         # Detailed documentation
│   └── DEPLOYMENT.md             # Step-by-step deployment guide (1000+ lines)
│
├── playbooks/                    # Ansible playbooks for Cloudflare automation
│   └── cloudflare/
│       ├── cloudflare_awx_playbook.yml      # Main playbook
│       ├── cloudflare_modern_rules.j2       # Rules template
│       ├── survey_spec.json.j2              # Survey configuration template
│       └── tasks/                           # Task files
│           ├── cloudflare_delete_dns_record.yml
│           ├── list_zones.yml
│           ├── manage_dns_record.yml
│           ├── prepare_record_variables.yml
│           ├── resolve_variables.yml
│           ├── validate_inputs.yml
│           └── ... (9 task files total)
│
└── scripts/                      # Management scripts
    └── awx_survey_manager.sh     # Survey management utility
```

---

## File Descriptions

### Root Level

#### `Makefile` (280 lines)
**Purpose**: Main automation interface  
**Key Targets**:
- `install-all` - Complete AWX installation
- `build-image` - Build patched AWX image
- `push-image` - Push image to registry
- `deploy-awx` - Deploy AWX instance
- `apply-survey` - Configure job template survey
- `update-dropdowns` - Populate with Cloudflare data
- `port-forward` - Access AWX UI
- `get-password` - Retrieve admin password
- `check-awx` - Verify installation

**Variables**: Registry, namespace, image tags, tokens

#### `README.md` (650 lines)
**Purpose**: Complete project documentation  
**Sections**:
- Features overview
- Prerequisites and requirements
- Quick start guide
- Detailed installation
- Configuration options
- Usage examples
- Architecture diagrams
- Troubleshooting guide
- Production considerations

#### `QUICKSTART.md` (330 lines)
**Purpose**: Get running in 15 minutes  
**Target Audience**: Users who want fastest path to working system  
**Includes**: Minimal steps, copy-paste commands, immediate testing

---

### `awx-image/` Directory

#### `Dockerfile`
**Purpose**: Build patched AWX image  
**Base Image**: `quay.io/ansible/awx:24.6.1`  
**Patch**: Replaces `jobs.py` to fix inventory dump functionality  
**Output**: `awx-cloudflare-auto:24.6.1-cf-auto`

#### `jobs.py`
**Purpose**: Patched jobs.py file  
**Fix**: Inventory dump issue in AWX 24.6.1  
**Integration**: Copied into AWX image during build

#### `README.md`
**Purpose**: Image building instructions  
**Includes**: Build commands, registry push, version management

---

### `config/` Directory

#### `.env.example` (195 lines)
**Purpose**: Environment variables template  
**Sections**:
- Cloudflare configuration (API token)
- AWX configuration (host, credentials)
- Kubernetes configuration (namespace, names)
- Docker/Registry configuration
- Resource configuration (CPU, memory, storage)
- Service configuration (ingress, TLS)
- Development/debug settings
- Backup configuration
- Monitoring/alerting settings
- Advanced settings

**Usage**: `cp .env.example .env` and fill in values

#### `awx-instance.yaml.example` (347 lines)
**Purpose**: AWX CustomResource configuration template  
**Sections**:
- Image configuration (registry, version, pull policy)
- Service configuration (ClusterIP, NodePort, LoadBalancer)
- Ingress configuration (hostname, TLS, annotations)
- Resource requirements (CPU, memory for all pods)
- Scaling configuration (replicas)
- Storage configuration (PostgreSQL, projects)
- External database setup (optional)
- Execution environment images
- Security configuration (admin, secrets)
- LDAP configuration (optional)
- Metrics & monitoring

**Usage**: Copy and customize for your cluster, then `kubectl apply`

---

### `docs/` Directory

#### `DEPLOYMENT.md` (1000+ lines)
**Purpose**: Comprehensive deployment guide  
**Sections**:

1. **Pre-Deployment Checklist**
   - Cluster requirements verification
   - Cloudflare setup confirmation
   - Local environment preparation
   - Files preparation checklist

2. **Architecture Overview**
   - Component diagram
   - Data flow explanation
   - Namespace organization

3. **Deployment Steps** (5 Phases)
   - Phase 1: Environment Preparation
   - Phase 2: AWX Operator Installation
   - Phase 3: AWX Instance Deployment
   - Phase 4: Cloudflare Configuration
   - Phase 5: Template & Survey Setup

4. **Post-Deployment Validation**
   - System health checks
   - UI access verification
   - Cloudflare integration testing
   - Template & survey validation
   - Test job execution

5. **Production Considerations**
   - Security hardening (TLS, network policies, RBAC)
   - High availability setup (replicas, external DB)
   - Backup strategies (PostgreSQL, AWX config)
   - Monitoring & alerting (Prometheus, alerts)

6. **Upgrade Procedures**
   - AWX operator upgrades
   - AWX instance upgrades
   - Playbook updates

7. **Rollback Procedures**
   - Deployment rollback
   - Database restoration
   - Verification steps

---

### `playbooks/cloudflare/` Directory

#### `cloudflare_awx_playbook.yml`
**Purpose**: Main Ansible playbook  
**Operations**: DNS record management (create, update, delete)  
**Tasks**: Imports all task files in sequence

#### `survey_spec.json.j2`
**Purpose**: Jinja2 template for AWX survey configuration  
**Fields**: 13 survey questions including:
- Operation (create/update/delete)
- Domain selection (dropdown)
- Record selection (dropdown)
- Manual entry fields
- Record type, target, TTL, proxy settings

#### `cloudflare_modern_rules.j2`
**Purpose**: Template for Cloudflare rules configuration  
**Use Case**: Advanced Cloudflare rule management (if extended)

#### `tasks/` (9 files)

##### `validate_inputs.yml`
**Purpose**: Validate survey inputs  
**Checks**: Required fields, valid values, operation type

##### `resolve_variables.yml`
**Purpose**: Resolve manual entry vs dropdown selection  
**Logic**: Manual entry takes priority over dropdown values  
**Variables**: domain, record_name, operation

##### `prepare_record_variables.yml`
**Purpose**: Build fully qualified record names  
**Logic**: Handles @ for root, FQDN detection, subdomain building  
**Validation**: Ensures record name not empty (EMPTY_RECORD_NAME flag)

##### `manage_dns_record.yml`
**Purpose**: Main DNS operation dispatcher  
**Operations**: Routes to create/update/delete based on operation variable

##### `cloudflare_delete_dns_record.yml`
**Purpose**: Delete DNS record  
**Method**: Cloudflare API DELETE request

##### `list_zones.yml`
**Purpose**: Retrieve all Cloudflare zones  
**Output**: List of zones for dropdown population

##### Other task files
Support functions for zone management, record lookup, validation

---

### `scripts/` Directory

#### `awx_survey_manager.sh`
**Purpose**: Unified survey management script  
**Functions**:

1. **apply-survey**
   - Applies survey configuration to template
   - Uses survey_spec.json.j2 template
   - Updates AWX via API

2. **update-dropdowns**
   - Fetches live Cloudflare zones and records
   - Updates survey dropdown options
   - Removes placeholder values

3. **verify-changes**
   - Displays current survey configuration
   - Compares with template
   - Shows differences

4. **update-template**
   - Updates template name and description
   - Modifies template settings

5. **show-current**
   - Displays current survey state
   - Shows all fields and options

**Requirements**: kubectl, jq, AWX credentials, Cloudflare token

---

## Workflow Overview

### Initial Setup Flow

```
1. User extracts CF_AWX_AUTO package
   ↓
2. User creates config/awx-instance.yaml from example
   ↓
3. User gets Cloudflare API token
   ↓
4. User runs: make install-all CLOUDFLARE_API_TOKEN=xxx
   ↓
5. Makefile executes:
   - install-operator (AWX Operator deployed)
   - create-secret (Cloudflare token stored)
   - deploy-awx (AWX instance created)
   ↓
6. User accesses AWX:
   - make get-password
   - make port-forward
   - Open http://localhost:8052
   ↓
7. User configures AWX UI:
   - Create Project
   - Create Inventory
   - Create Job Template
   ↓
8. User applies survey:
   - make apply-survey
   - make update-dropdowns CLOUDFLARE_API_TOKEN=xxx
   ↓
9. User launches jobs:
   - Select template
   - Fill survey
   - Execute Cloudflare operations
```

### Daily Usage Flow

```
1. User opens AWX UI (http://localhost:8052)
   ↓
2. Navigate to Templates → "Cloudflare - Automation"
   ↓
3. Click Launch
   ↓
4. Fill survey (dropdowns pre-populated with Cloudflare data)
   ↓
5. Click Launch
   ↓
6. AWX executes playbook
   ↓
7. Playbook calls Cloudflare API
   ↓
8. Changes applied to Cloudflare
   ↓
9. Results displayed in AWX UI
```

### Survey Update Flow

```
1. Changes made in Cloudflare dashboard (new zones/records)
   ↓
2. User runs: make update-dropdowns CLOUDFLARE_API_TOKEN=xxx
   ↓
3. Script fetches latest Cloudflare data
   ↓
4. Survey dropdowns updated via AWX API
   ↓
5. Next job launch shows current Cloudflare state
```

---

## Target Use Cases

### Development/Testing
- Local Kubernetes (kind, minikube, k3s)
- Minimal resources (4 CPU, 8GB RAM)
- Single namespace deployment
- Port-forward for access
- No ingress required

### Staging/QA
- Cloud Kubernetes (GKE, EKS, AKS)
- Medium resources (8 CPU, 16GB RAM)
- Ingress with staging domain
- TLS with Let's Encrypt staging
- Test Cloudflare zones

### Production
- Production Kubernetes cluster
- High resources (16+ CPU, 32+ GB RAM)
- Multiple replicas (HA)
- External PostgreSQL
- Ingress with production domain
- TLS with Let's Encrypt prod
- Monitoring & alerting
- Backup strategy
- Production Cloudflare zones

---

## File Statistics

| Category | Files | Lines | Purpose |
|----------|-------|-------|---------|
| Documentation | 4 | 2,500+ | Setup, usage, troubleshooting |
| Configuration | 2 | 542 | Environment and deployment config |
| Automation | 1 | 280 | Makefile targets |
| Image Build | 3 | 150 | Patched AWX image |
| Playbooks | 1 | 100 | Main Cloudflare automation |
| Templates | 2 | 200 | Survey and rules |
| Tasks | 9 | 600 | Ansible task files |
| Scripts | 1 | 400 | Survey management |
| **Total** | **23** | **4,772** | Complete package |

---

## Key Features Summary

### Plug-and-Play
- Pre-built patched AWX image available
- One-command installation
- Automated configuration
- No manual file editing required

### Production-Ready
- Resource limits configured
- Security best practices
- HA configuration examples
- Backup procedures documented

### Flexible
- Works on any Kubernetes
- Customizable resources
- Optional ingress
- External database support

### Well-Documented
- Quick start (15 min)
- Full deployment guide
- Troubleshooting section
- Architecture diagrams

### Maintainable
- Makefile for common operations
- Survey management script
- Clear file organization
- Version controlled

---

## Next Steps for Users

1. **Read** `QUICKSTART.md` for fastest setup
2. **Or Read** `README.md` for comprehensive overview
3. **Create** `config/awx-instance.yaml` from example
4. **Run** `make install-all`
5. **Access** AWX UI and configure
6. **Start** managing Cloudflare!

For production deployment, follow `docs/DEPLOYMENT.md` for complete guide including security, HA, and monitoring setup.

---

**Package is ready to ship!**
