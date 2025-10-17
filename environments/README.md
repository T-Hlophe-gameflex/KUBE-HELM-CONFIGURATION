# =============================================================================
# 🌍 ENVIRONMENT CONFIGURATION GUIDE
# =============================================================================

This directory contains environment-specific configuration files for different deployment scenarios.

## 📁 Available Environments

### 🏗️ Development (`development.env`)
- **Purpose**: Local development with minimal resource usage
- **Resources**: Reduced CPU/memory for laptop development
- **Features**: Debug mode enabled, single replicas
- **Services**: Internal access only (no LoadBalancer)
- **Storage**: Minimal storage allocations

### 🧪 Testing (`testing.env`) 
- **Purpose**: Automated testing and CI/CD pipelines
- **Resources**: Moderate resources for testing scenarios
- **Features**: Full feature testing, cleanup enabled
- **Services**: External access for testing
- **Storage**: Temporary storage with quick cleanup

### 🚀 Production (`production.env`)
- **Purpose**: High availability production deployments
- **Resources**: Full resource allocation for performance
- **Features**: All production features enabled
- **Services**: Full external access with SSL
- **Storage**: High-performance storage with backups

## 🔧 Usage

### Option 1: Copy Template
```bash
# Copy the template and customize
cp .env.template .env
# Edit .env with your specific values
```

### Option 2: Use Environment-Specific File
```bash
# Use a pre-configured environment
cp environments/development.env .env
# Or
cp environments/production.env .env
```

### Option 3: Environment-Specific Deployment
```bash
# Load specific environment during deployment
export ENV_FILE=environments/development.env
make deploy-complete

# Or pass directly to scripts
./scripts/deploy.sh --env-file environments/production.env
```

## 🔐 Security Configuration

### Development
- Simple passwords for local testing
- Debug logging enabled
- Reduced security validations

### Testing  
- Test-specific credentials
- Moderate security settings
- Full logging for troubleshooting

### Production
- Strong passwords and secrets
- Full security validations
- Audit logging enabled
- SSL/TLS encryption

## ⚙️ Key Configuration Areas

### 1. Resource Allocation
```bash
# Development
ELASTICSEARCH_MEMORY=1Gi
ORDER_SERVICE_REPLICAS=1

# Production  
ELASTICSEARCH_MEMORY=4Gi
ORDER_SERVICE_REPLICAS=3
```

### 2. Feature Flags
```bash
# Development
ENABLE_METALLB=false
ENABLE_SSL=false

# Production
ENABLE_METALLB=true
ENABLE_SSL=true
```

### 3. Storage Configuration
```bash
# Development
ELASTICSEARCH_STORAGE=5Gi
STORAGE_CLASS=standard

# Production
ELASTICSEARCH_STORAGE=50Gi
STORAGE_CLASS=fast-ssd
```

## 🚀 Quick Start Examples

### Development Deployment
```bash
# Setup for local development
cp environments/development.env .env
make setup
make deploy-elk
```

### Production Deployment
```bash
# Setup for production
cp environments/production.env .env
# Update CLOUDFLARE_API_TOKEN and passwords
make setup
make deploy-complete
```

### Testing Pipeline
```bash
# Automated testing deployment
export ENV_FILE=environments/testing.env
make setup
make deploy-complete
make validate
make clean
```

## 🔄 Environment Switching

### Switch Between Environments
```bash
# Switch to development
cp environments/development.env .env
make remove-complete
make deploy-complete

# Switch to production
cp environments/production.env .env
make remove-complete
make deploy-complete
```

### Validate Environment
```bash
# Check current configuration
make check-env
make info
```

## 📊 Resource Planning

### Development Requirements
- **CPU**: 2-4 cores
- **Memory**: 4-8 GB RAM
- **Storage**: 10-20 GB
- **Network**: Local Kind cluster

### Testing Requirements  
- **CPU**: 4-6 cores
- **Memory**: 8-12 GB RAM
- **Storage**: 20-40 GB
- **Network**: CI/CD environment

### Production Requirements
- **CPU**: 8-16 cores
- **Memory**: 16-32 GB RAM  
- **Storage**: 100-500 GB
- **Network**: Production cluster

## 🔒 Security Best Practices

### 1. Secrets Management
```bash
# Never commit real secrets
cp .env.template .env
# Add .env to .gitignore
echo ".env" >> .gitignore
```

### 2. Environment Isolation
```bash
# Use different namespaces per environment
ELK_NAMESPACE=elk-dev      # Development
ELK_NAMESPACE=elk-test     # Testing  
ELK_NAMESPACE=elastic-stack # Production
```

### 3. Access Control
```bash
# Development: Internal access only
EXPOSE_SERVICES=false

# Production: Controlled external access
EXPOSE_SERVICES=true
ENABLE_SSL=true
```

## 🛠️ Customization

### Creating Custom Environment
```bash
# Create new environment file
cp environments/production.env environments/staging.env
# Customize for your staging environment
# Update namespaces, resources, and features
```

### Environment Variables Priority
1. Command line arguments (highest)
2. `.env` file in project root
3. Environment-specific file (if specified)
4. Default values in scripts (lowest)

## 📝 Validation

### Environment Validation
```bash
# Validate environment configuration
make check-env

# Test deployment with dry-run
./scripts/deploy.sh --dry-run

# Validate after deployment
make validate
```

## 🆘 Troubleshooting

### Common Issues

#### Resource Constraints
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Reduce resources in environment file
ELASTICSEARCH_MEMORY=1Gi  # Instead of 4Gi
```

#### Configuration Errors
```bash
# Validate configuration
make check-env

# Check environment loading
source .env && env | grep -E "(ELK|APP|CLOUDFLARE)"
```

#### Deployment Failures
```bash
# Check specific environment deployment
export ENV_FILE=environments/development.env
make validate

# Check logs for issues
make logs
```