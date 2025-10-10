# Scripts

Utility scripts for cluster setup, deployment, and testing.

## Available Scripts

### Core Setup Scripts

#### setup-kind.sh
Creates a basic Kind cluster with ELK Stack.

```bash
./scripts/setup-kind.sh
```

#### setup-kind-with-awx.sh (NEW)
Creates a complete Kind cluster with ELK Stack, AWX, and Cloudflare integration.

```bash
./scripts/setup-kind-with-awx.sh
```

**Features:**
- Complete ELK Stack deployment
- AWX automation platform with web UI
- Cloudflare DNS integration
- PostgreSQL database
- Order and User services
- Automatic port mapping for AWX (localhost:30080)

### setup-kubespray.sh
Creates a Kubespray cluster for production environments.

```bash
make setup
```

### Testing Scripts

#### test-cloudflare-dns.sh (NEW)
Tests Cloudflare DNS integration with the deployed cluster.

```bash
./scripts/test-cloudflare-dns.sh
```

**Prerequisites:**
- Running Kubernetes cluster
- .env file with CLOUDFLARE_API_TOKEN and FIRST_DOMAIN

**Tests performed:**
- API connectivity verification
- Single DNS record creation
- Bulk DNS record creation
- Job execution validation

### generate-sample-logs.sh
Generates test logs for ELK Stack validation.

```bash
make generate-logs
```

**Generated log data includes:**
- Multiple log levels (INFO, WARN, ERROR, DEBUG)
- Multiple services (order, user, payment, notification)
- HTTP metadata (status codes, response times)
- Kubernetes pod metadata

**Old way**:
```bash
./scripts/test-elk-deployment.sh
```

**New way**:
```bash
make test
# Or: helm test elk-stack-platform -n monitoring
```

**Why**: Helm has built-in testing capabilities. Tests are now Kubernetes pods that run validation and clean up automatically.

---

#### `verify-setup.sh` ❌
**Replaced by**: Helm test pods (same as above)

**Old way**:
```bash
./scripts/verify-setup.sh
```

**New way**:
```bash
make test
```

**Why**: Same functionality as `test-elk-deployment.sh`, but now using Helm's native testing.

---

#### `setup-kibana-dataviews.sh` ❌
**Replaced by**: Helm post-install hook in `helm-charts/templates/hooks/post-install-kibana-setup.yaml`

**Old way**:
```bash
# Manual execution after deployment
./scripts/setup-kibana-dataviews.sh
```

**New way**:
```bash
make deploy
# Kibana Data Views are created automatically!
```

**Why**: Helm hooks run automatically as part of the deployment lifecycle. No manual intervention needed!

---

## What Changed?

### Before (Script-Heavy)
```
scripts/
├── deploy-helm.sh              # 300+ lines
├── test-elk-deployment.sh      # 150+ lines
├── verify-setup.sh             # 150+ lines
├── setup-kibana-dataviews.sh   # 165 lines
├── setup-simple.sh             # Keep
└── generate-sample-logs.sh     # Keep
```
**Total**: 765+ lines of bash (excluding keepers)

### After (Helm-Native)
```
scripts/
├── setup-simple.sh             # Infrastructure (keep)
├── generate-sample-logs.sh     # Testing utility (keep)
└── README.md                   # This file

scripts-old/                     # Archived
├── deploy-helm.sh              
├── test-elk-deployment.sh      
├── verify-setup.sh             
└── setup-kibana-dataviews.sh   
```
**Reduction**: **765+ lines eliminated!** 🎉

---

## How to Use the New Approach

### Deployment
```bash
make deploy              # Deploy complete stack
make deploy-elk          # Deploy ELK only
make upgrade             # Upgrade deployment
make remove              # Uninstall
```

### Testing
```bash
make test                # Run all Helm tests
make status              # Check deployment
make validate            # Validate config
```

### Access
```bash
make kibana              # Access Kibana
make elasticsearch       # Access Elasticsearch
make logs-elasticsearch  # View logs
```

### Utilities
```bash
make setup               # Create cluster
make generate-logs       # Sample logs
make clean               # Delete cluster
```

---

## Benefits

### ✅ Simplicity
- **87% less code**: 765+ lines → ~200 lines
- **No hidden logic**: Everything is in Makefile or Helm templates
- **Self-documenting**: Standard Kubernetes patterns

### ✅ Reliability
- **Atomic operations**: Helm handles failures
- **Automatic retry**: Built-in retry logic
- **Rollback support**: `make rollback` to undo

### ✅ Production-Ready
- **GitOps compatible**: Works with ArgoCD, Flux
- **CI/CD friendly**: Standard helm commands
- **Standard practices**: No custom tooling

### ✅ Maintainability
- **Declarative**: YAML instead of bash
- **Version controlled**: Everything in Git
- **Easy to understand**: Clear structure

---

## Migration Notes

If you need the old scripts temporarily, they're in `scripts-old/`:

```bash
# Old deployment
./scripts-old/deploy-helm.sh deploy all

# Old testing
./scripts-old/test-elk-deployment.sh

# Old Kibana setup
./scripts-old/setup-kibana-dataviews.sh
```

But we **strongly recommend** using the new Helm-native approach! 🚀

---

## Learn More

- **Helm-Native Approach**: See `HELM_NATIVE_REFACTORING.md`
- **Consolidation Plan**: See `SCRIPT_CONSOLIDATION_PLAN.md`
- **Main README**: See `README.md` for complete usage

---

## Summary

**Keep**: 2 scripts (infrastructure + testing utility)  
**Archived**: 4 scripts (765+ lines)  
**Replaced with**: Helm hooks, tests, and direct commands  
**Result**: Simpler, more reliable, production-ready! ✨
