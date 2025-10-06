# Scripts

Utility scripts for cluster setup and testing.

## Available Scripts

### setup-simple.sh
Creates a local Kind cluster for development.

```bash
make setup
# Or directly: ./scripts/setup-simple.sh
```

### generate-sample-logs.sh
Generates realistic test logs for ELK Stack validation.

```bash
make generate-logs
# Or directly: ./scripts/generate-sample-logs.sh 50
```

**Generates:**
- Multiple log levels (INFO, WARN, ERROR, DEBUG)
- Multiple services (order, user, payment, notification, analytics)
- HTTP metadata (status codes, response times)
- Trace IDs for distributed tracing
- Kubernetes pod metadata

The following scripts have been **archived** and replaced with Helm-native features:

#### `deploy-helm.sh` ❌
**Replaced by**: Direct `helm upgrade --install` commands in `Makefile`

**Old way**:
```bash
./scripts/deploy-helm.sh deploy all
```

**New way**:
```bash
make deploy
```

**Why**: The 300+ lines of bash logic are now handled by Helm natively. The Makefile shows exactly what's being deployed - no hidden logic!

---

#### `test-elk-deployment.sh` ❌
**Replaced by**: Helm test pods in `helm-charts/templates/tests/`

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
