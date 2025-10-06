# Kubernetes ELK Stack + Microservices Platform

Production-ready logging infrastructure with business applications using Helm, Ansible, and Kubespray.

## 🚀 Quick Start

```bash
make setup    # Create Kind cluster
make deploy   # Deploy full stack (ELK + MetalLB + Services)
make test     # Run health checks
make kibana   # Access Kibana → http://localhost:5601
```

## 🏗️ Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT LAYER                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Ansible Playbooks  ──────> Helm Charts ──────> Kubernetes          │
│  (Orchestration)            (Individual)         (Kind/Kubespray)    │
│                                                                       │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                    ┌───────────┴────────────┐
                    │                        │
        ┌───────────▼──────────┐  ┌─────────▼────────────┐
        │   OBSERVABILITY      │  │   APPLICATION LAYER  │
        │   (Namespace: monitoring) │   (Namespace: backend/database) │
        ├──────────────────────┤  ├──────────────────────┤
        │                      │  │                      │
        │  Elasticsearch ───┐  │  │  Order Service ────┐ │
        │       ▲           │  │  │       │            │ │
        │       │           ▼  │  │       ▼            │ │
        │  Logstash ───> Kibana│  │  PostgreSQL        │ │
        │       ▲              │  │       ▲            │ │
        │       │              │  │       │            │ │
        │  Filebeat ───────────┘  │  User Service ─────┘ │
        │  (DaemonSet)            │                      │
        └──────────────────────┘  └──────────────────────┘
                    │
        ┌───────────▼──────────────────────┐
        │   INFRASTRUCTURE LAYER           │
        │   (Namespace: metallb-system)    │
        ├──────────────────────────────────┤
        │                                  │
        │  MetalLB LoadBalancer            │
        │  IP Pool: 172.18.255.200-250     │
        │                                  │
        │  ┌────────────────────────────┐  │
        │  │ External IPs Assigned:     │  │
        │  │ • Elasticsearch: .200      │  │
        │  │ • Kibana: .202             │  │
        │  └────────────────────────────┘  │
        └──────────────────────────────────┘
```

## 📁 Project Structure

```text
helm-charts/charts/
├── elasticsearch/     # Search & analytics (config/application-template.json)
├── kibana/           # Visualization dashboard
├── logstash/         # Log processing (config/logstash-template.json)
├── filebeat/         # Log collector (config/filebeat-template.json)
├── metallb/          # LoadBalancer config
└── services/         # Business services
    ├── order-service/  # Order management REST API (Node.js)
    ├── user-service/   # User management REST API (Node.js)
    └── postgres/       # PostgreSQL 15 database

playbooks/                 # Ansible automation
├── main.yml              # Main orchestrator
└── tasks/
    ├── deploy-helm.yml   # Deploy all charts
    ├── remove-helm.yml   # Remove all releases
    └── validate-cluster.yml

inventory/mycluster/       # Kubespray cluster config
scripts/                   # Utility scripts (setup, generate-logs)
```

## 🛠️ Prerequisites

- Kubernetes 1.20+ (Kind for local development)
- Helm 3.x
- Ansible 2.9+
- kubectl configured

## 📦 Deployment

```bash
# Complete setup (recommended)
make setup && make deploy

# Using Ansible directly
ansible-playbook playbooks/main.yml -e action=deploy

# Deploy specific components
ansible-playbook playbooks/main.yml -e action=deploy \
  -e deploy_postgres=true \
  -e deploy_order_service=true \
  -e deploy_user_service=true
```

## ✅ Verification

```bash
make test     # Run Helm tests
make status   # Check pod status
make kibana   # Access Kibana UI
```

## 🔧 Common Operations

```bash
# Access services
make kibana           # Port-forward to Kibana (5601)
make elasticsearch    # Port-forward to Elasticsearch (9200)

# Management
make upgrade          # Upgrade deployment
make remove           # Uninstall deployment
make clean            # Delete cluster

# Utilities
make generate-logs    # Generate sample logs
```

## 📊 Services & Endpoints

| Service | Namespace | Port | Access |
|---------|-----------|------|--------|
| Elasticsearch | monitoring | 9200 | LoadBalancer (172.18.255.200) |
| Kibana | monitoring | 5601 | LoadBalancer (172.18.255.202) |
| Logstash | monitoring | 5044, 9600 | ClusterIP |
| Filebeat | monitoring | - | DaemonSet |
| PostgreSQL | database | 5432 | ClusterIP |
| Order Service | backend | 8080 | ClusterIP |
| User Service | backend | 8081 | ClusterIP |

## 🐛 Troubleshooting

```bash
# Check status
kubectl get pods -A
kubectl get svc -A

# View logs
kubectl logs -n monitoring deployment/elasticsearch
kubectl logs -n monitoring deployment/kibana

# Debug connectivity
kubectl exec -it -n monitoring deployment/elasticsearch -- curl http://localhost:9200
```
