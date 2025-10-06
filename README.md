# Kubernetes ELK Stack Platform

Production logging infrastructure with microservices using Helm, Ansible, and Kubespray.

## Quick Start

```bash
make setup    # Create cluster
make deploy   # Deploy ELK stack and services
make status   # Check deployment status
make kibana   # Access Kibana at http://localhost:5601
```

## Architecture

```mermaid
graph TB
    subgraph "Deployment Layer"
        A[Ansible Playbooks] --> B[Helm Charts]
        B --> C[Kubernetes Cluster]
    end
    
    subgraph "Kubernetes Cluster"
        subgraph "monitoring namespace"
            ES[Elasticsearch<br/>:9200]
            KB[Kibana<br/>:5601]
            LS[Logstash<br/>:5044]
            FB[Filebeat<br/>DaemonSet]
            
            FB --> LS
            LS --> ES
            ES --> KB
        end
        
        subgraph "backend namespace"
            OS[Order Service<br/>:8080]
            US[User Service<br/>:8081]
        end
        
        subgraph "database namespace"
            PG[PostgreSQL<br/>:5432]
        end
        
        subgraph "metallb-system namespace"
            MLB[MetalLB<br/>LoadBalancer<br/>172.18.255.200-250]
        end
        
        OS --> PG
        US --> PG
        OS -.-> FB
        US -.-> FB
        
        MLB --> ES
        MLB --> KB
    end
    
    C --> monitoring
    C --> backend
    C --> database
    C --> metallb-system
    
    classDef observability fill:#e1f5fe
    classDef application fill:#f3e5f5
    classDef database fill:#e8f5e8
    classDef infrastructure fill:#fff3e0
    
    class ES,KB,LS,FB observability
    class OS,US application
    class PG database
    class MLB infrastructure
```

### Data Flow

```mermaid
sequenceDiagram
    participant User
    participant Kibana
    participant Elasticsearch
    participant Logstash
    participant Filebeat
    participant Apps as Applications<br/>(Order/User Services)
    
    Apps->>Filebeat: Generate logs
    Filebeat->>Logstash: Ship log data
    Logstash->>Logstash: Process & transform
    Logstash->>Elasticsearch: Index processed logs
    User->>Kibana: Access dashboard
    Kibana->>Elasticsearch: Query log data
    Elasticsearch->>Kibana: Return results
    Kibana->>User: Display visualizations
```

## Project Structure

```text
helm-charts/charts/
├── elasticsearch/     # Search and analytics engine
├── kibana/           # Data visualization dashboard
├── logstash/         # Log processing pipeline
├── filebeat/         # Log data shipper
├── metallb/          # Load balancer configuration
└── services/         # Application services
    ├── order-service/  # Order management API
    ├── user-service/   # User management API
    └── postgres/       # PostgreSQL database

playbooks/                 # Ansible deployment automation
├── main.yml              # Main orchestration playbook
└── tasks/
    ├── deploy-helm.yml   # Deploy all Helm charts
    ├── remove-helm.yml   # Remove all deployments
    └── validate-cluster.yml # Validate cluster state

inventory/mycluster/       # Kubespray cluster configuration
scripts/                   # Utility scripts
```

## Prerequisites

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
