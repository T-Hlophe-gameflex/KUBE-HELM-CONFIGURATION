# 🚀 Kubernetes Infrastructure Automation Platform

> **Complete automation framework for deploying ELK stack, application services, and Cloudflare DNS management**

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Kubernetes-blue.svg)](https://kubernetes.io/)
[![Automation](https://img.shields.io/badge/Automation-Ansible-red.svg)](https://ansible.com/)
[![DNS](https://img.shields.io/badge/DNS-Cloudflare-orange.svg)](https://cloudflare.com/)
[![Monitoring](https://img.shields.io/badge/Monitoring-ELK%20Stack-yellow.svg)](https://elastic.co/)

## 🎯 Project Overview

This comprehensive automation platform provides everything needed to deploy and manage a complete Kubernetes infrastructure including:

- **🔍 ELK Stack**: Elasticsearch, Logstash, Kibana, and Filebeat for comprehensive logging
- **🚀 Application Services**: PostgreSQL, Order Service, and User Service with full configuration
- **🌐 Cloudflare DNS**: Dynamic DNS management with interactive domain selection
- **⚖️ Load Balancing**: MetalLB integration for external service access
- **🔧 Complete Automation**: One-command deployment and cleanup scripts

## ✨ Key Features

### 🎛️ **Multiple Deployment Modes**
- **Complete**: Full infrastructure (ELK + Apps + MetalLB)
- **ELK Only**: Just the logging stack
- **Apps Only**: Application services without logging
- **Cluster**: Complete cluster management

### 🌍 **Environment Support**
- **Development**: Minimal resources for local testing
- **Testing**: CI/CD optimized configuration
- **Production**: High-availability setup

### 🔐 **Security & Configuration**
- Environment-specific configurations
- Secure secret management
- JWT token integration
- SSL/TLS support

### 📊 **Monitoring & Management**
- Comprehensive health checks
- Automated backup system
- Real-time log aggregation
- Port-forwarding automation

## 🚀 Quick Start

### 1. **Prerequisites Setup**
```bash
# Install dependencies
make install-deps

# Setup Python environment and cluster
make setup

# Verify environment
make check-env
```

### 2. **Configure Environment**
```bash
# Copy and configure environment
cp .env.template .env
# Edit .env with your Cloudflare API token and preferences

# Or use pre-configured environment
cp environments/development.env .env
```

### 3. **Deploy Infrastructure**
```bash
# Deploy everything
make deploy-complete

# Or deploy specific components
make deploy-elk     # ELK stack only
make deploy-apps    # Application services only
```

### 4. **Access Services**
```bash
# Access Kibana dashboard
make kibana

# Check deployment status
make status

# View logs
make logs
```

## 📋 Available Commands

### 🔧 **Setup & Prerequisites**
```bash
make setup-python      # Configure Python environment
make setup-cluster     # Create Kubernetes cluster
make setup             # Complete setup
make check-env         # Validate environment
```

### 🚀 **Deployment**
```bash
make deploy-complete   # Deploy everything
make deploy-elk        # Deploy ELK stack only
make deploy-apps       # Deploy applications only
make cloudflare-dns    # Manage DNS records
```

### 🧹 **Cleanup**
```bash
make remove-complete   # Remove all deployments
make remove-elk        # Remove ELK stack
make remove-apps       # Remove applications
make clean-cluster     # Delete entire cluster
```

### 📊 **Monitoring & Access**
```bash
make status           # Show deployment status
make validate         # Run health checks
make kibana          # Access Kibana (localhost:5601)
make elasticsearch   # Access Elasticsearch (localhost:9200)
make logs            # View application logs
```

### 💾 **Backup & Utilities**
```bash
make backup          # Create deployment backup
make restore         # Restore from backup
make generate-logs   # Generate sample logs
make info           # Show cluster information
```

## 🌍 Environment Configuration

### **Development Environment**
```bash
cp environments/development.env .env
make deploy-elk
```

- Minimal resource usage
- Single replicas
- Internal access only
- Perfect for local development

### **Production Environment**
```bash
cp environments/production.env .env
make deploy-complete
```

- High availability (3 replicas)
- Full resource allocation
- External LoadBalancer access
- SSL/TLS enabled

### **Testing Environment**
```bash
cp environments/testing.env .env
make deploy-complete
```

- CI/CD optimized
- Moderate resources
- Automated cleanup
- Full feature testing

## 🌐 Cloudflare DNS Management

### **Interactive DNS Management**
```bash
# Set your API token
export CLOUDFLARE_API_TOKEN=your_token_here

# Run interactive DNS management
make cloudflare-dns
```

**Features:**

- 🔍 **Domain Discovery**: Automatically fetch your domains
- 📋 **Interactive Selection**: Choose domains from dropdown
- ✏️ **CRUD Operations**: Create, update, delete DNS records
- ✅ **Validation**: API connectivity and permission checks

## 📊 ELK Stack Details

### **Components Deployed**

- **Elasticsearch**: Search and analytics engine (configurable replicas)
- **Kibana**: Data visualization dashboard
- **Logstash**: Data processing pipeline
- **Filebeat**: Log shipping agent (DaemonSet)

### **Default Configuration**
```yaml
Elasticsearch: 1-3 replicas, 2-4Gi memory
Kibana: Single instance, 1-2Gi memory
Logstash: Single instance, 1-2Gi memory
Filebeat: DaemonSet on all nodes
```

### **Storage**

- Persistent volumes for Elasticsearch data
- Configurable storage classes
- Automatic volume expansion support

## 🚀 Application Services

### **Deployed Applications**

- **PostgreSQL**: Primary database with persistent storage
- **Order Service**: Microservice with configurable replicas
- **User Service**: Microservice with configurable replicas

### **Features**

- ConfigMap-based configuration
- Secret management for credentials
- Health checks and readiness probes
- Horizontal scaling support
- Load balancer integration

## ⚙️ Configuration Options

### **Key Variables**
```bash
DEPLOYMENT_MODE=complete          # complete, elk-only, apps-only
ELK_NAMESPACE=elastic-stack      # ELK components namespace
APP_NAMESPACE=app-services       # Application namespace
EXPOSE_SERVICES=true             # Enable LoadBalancer services
ELASTICSEARCH_MEMORY=2Gi         # Elasticsearch memory allocation
POSTGRES_PASSWORD=changeme123    # Database password
```

### **Resource Customization**
```bash
# Development resources
ELASTICSEARCH_MEMORY=1Gi
ORDER_SERVICE_REPLICAS=1

# Production resources
ELASTICSEARCH_MEMORY=4Gi
ORDER_SERVICE_REPLICAS=3
```

## 🔧 Advanced Usage

### **Custom Deployments**
```bash
# Deploy with custom configuration
make deploy-complete \
  ELASTICSEARCH_MEMORY=4Gi \
  ORDER_SERVICE_REPLICAS=3 \
  EXPOSE_SERVICES=true
```

### **Environment-Specific Deployment**
```bash
# Use specific environment file
export ENV_FILE=environments/production.env
make deploy-complete
```

### **Script-Based Deployment**
```bash
# Direct script usage with options
./scripts/deploy.sh \
  --mode complete \
  --elk-namespace my-elk \
  --app-namespace my-apps \
  --expose-services true
```

## 🛠️ Troubleshooting

### **Common Issues**

#### **Resource Constraints**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Reduce resources in environment
ELASTICSEARCH_MEMORY=1Gi
```

#### **Port Conflicts**
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart port forwards
make kibana
```

#### **DNS Issues**
```bash
# Test Cloudflare connectivity
make test-cloudflare

# Check API token permissions
curl -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/user"
```

### **Debug Mode**
```bash
# Enable verbose output
export VERBOSE=true
make deploy-complete

# Check specific component logs
kubectl logs -n elastic-stack -l app=elasticsearch
kubectl logs -n app-services -l app=postgres
```

## 📁 Project Structure

```text
├── automation/                 # Ansible playbooks
│   ├── cloudflare-dns-dynamic.yml
│   ├── deploy-elk-stack.yml
│   ├── deploy-app-services.yml
│   └── deploy-complete-infrastructure.yml
├── environments/               # Environment configurations
│   ├── development.env
│   ├── production.env
│   ├── testing.env
│   └── README.md
├── scripts/                   # Deployment scripts
│   ├── deploy.sh
│   ├── cleanup.sh
│   └── setup-kind.sh
├── helm-charts/              # Helm charts (legacy)
├── .env.template            # Environment template
├── Makefile                 # Main automation interface
└── README.md               # This file
```

## 🤝 Contributing

### **Development Setup**
```bash
# Clone and setup
git clone <repository>
cd KUBE-HELM-CONFIGURATION
make setup

# Create feature branch
git checkout -b feature/new-component

# Test changes
make deploy-elk
make validate
```

### **Adding New Components**

1. Create Ansible playbook in `automation/`
2. Add deployment logic to `scripts/deploy.sh`
3. Update Makefile with new targets
4. Add environment configuration options
5. Update documentation

## 📞 Support

### **Getting Help**

- 📖 Check the [Environment Configuration Guide](environments/README.md)
- 🔍 Run `make help` for command reference
- 🧪 Use `make check-env` to validate setup
- 📊 Use `make status` to check deployment state

### **Common Commands for Troubleshooting**
```bash
# Check everything
make check-env && make status && make validate

# Reset environment
make clean && make setup && make deploy-complete

# View comprehensive logs
make logs
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**🎉 Ready to deploy your infrastructure? Start with `make setup` and then `make deploy-complete`!**

- Kubernetes 1.20+
- Helm 3.x
- Ansible 2.9+
- kubectl configured

## Deployment

```bash
# Complete deployment
make setup && make deploy

# Deploy using Ansible directly
ansible-playbook playbooks/main.yml -e action=deploy

# Deploy specific components
ansible-playbook playbooks/main.yml -e action=deploy \
  -e deploy_postgres=true \
  -e deploy_order_service=true
```

## Verification

```bash
make status   # Check deployment status
make kibana   # Access Kibana interface
```

## Operations

```bash
# Access services
make kibana           # Port-forward to Kibana (5601)

# Management
make remove           # Remove deployments
make clean            # Delete cluster

# Generate test data
make generate-logs    # Generate sample log entries
```

## Services

| Service | Namespace | Port | Access |
|---------|-----------|------|--------|
| Elasticsearch | monitoring | 9200 | LoadBalancer |
| Kibana | monitoring | 5601 | LoadBalancer |
| Logstash | monitoring | 5044, 9600 | ClusterIP |
| Filebeat | monitoring | - | DaemonSet |
| PostgreSQL | database | 5432 | ClusterIP |
| Order Service | backend | 8080 | ClusterIP |
| User Service | backend | 8081 | ClusterIP |

## Troubleshooting

```bash
# Check deployment status
kubectl get pods -A
kubectl get svc -A

# View component logs
kubectl logs -n monitoring deployment/elasticsearch
kubectl logs -n monitoring deployment/kibana

# Test connectivity
kubectl exec -it -n monitoring deployment/elasticsearch -- curl http://localhost:9200
```
