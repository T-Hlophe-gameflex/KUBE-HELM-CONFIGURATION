# ELK Stack Helm Charts

Helm charts for deploying ELK Stack with microservices.

## Charts Structure

```text
charts/
├── elasticsearch/    # Search and analytics engine
├── kibana/          # Data visualization interface  
├── logstash/        # Log processing pipeline
├── filebeat/        # Log data collector
├── metallb/         # Load balancer configuration
└── services/        # Application services
    ├── order-service/  # Order management API
    ├── user-service/   # User management API
    └── postgres/       # PostgreSQL database
```

## Deployment

```bash
# ELK stack components
helm upgrade --install elasticsearch ./charts/elasticsearch -n monitoring --create-namespace
helm upgrade --install kibana ./charts/kibana -n monitoring
helm upgrade --install logstash ./charts/logstash -n monitoring
helm upgrade --install filebeat ./charts/filebeat -n monitoring

# Services and infrastructure
helm upgrade --install metallb ./charts/metallb -n metallb-system --create-namespace
helm upgrade --install postgres ./charts/services/postgres -n database --create-namespace
helm upgrade --install order-service ./charts/services/order-service -n backend --create-namespace
helm upgrade --install user-service ./charts/services/user-service -n backend
```

## Prerequisites

- Kubernetes 1.20+
- Helm 3.x

## Testing

```bash
helm test elasticsearch -n monitoring
helm test kibana -n monitoring
```

## Configuration

Each chart has its own `values.yaml` file. Key configuration options:

**Elasticsearch** (`charts/elasticsearch/values.yaml`)
- `replicaCount`: Number of replicas (default: 1)
- `clusterName`: Cluster name (default: k8s-logging-cluster)
- `javaOpts`: JVM options (default: "-Xms512m -Xmx512m")
- `persistence.enabled`: Enable persistent storage (default: false)
- `persistence.size`: Storage size (default: 10Gi)

**Kibana** (`charts/kibana/values.yaml`)
- `elasticsearchHosts`: ES connection URL
- `service.type`: Service type (default: ClusterIP)
- `service.port`: Service port (default: 5601)

**MetalLB** (`charts/metallb/values.yaml`)
- `addresses`: IP pool range (default: 172.18.255.200-172.18.255.250)

**PostgreSQL** (`charts/services/applications/postgres/values.yaml`)
- `auth.postgresPassword`: Admin password
- `auth.username`: App username (default: platform_user)
- `auth.database`: App database (default: platform_db)
- `persistence.size`: Storage size (default: 10Gi)

**Services** (`charts/services/applications/{order,user}-service/values.yaml`)
- `replicaCount`: Number of replicas (default: 2)
- `resources`: CPU/memory limits
- `database`: Database connection config

## Accessing Services

```bash
# Kibana
kubectl port-forward -n monitoring svc/kibana 5601:5601

# Order Service
kubectl port-forward -n backend svc/order-service 8080:8080

# User Service
kubectl port-forward -n backend svc/user-service 8081:8081

# PostgreSQL
kubectl port-forward -n database svc/postgres 5432:5432
```

## Troubleshooting

```bash
# Check status
kubectl get pods -A
helm list -A

# View logs
kubectl logs -n monitoring deployment/elasticsearch
kubectl logs -n monitoring deployment/kibana

# Debug templates
helm template ./charts/elasticsearch --debug
helm lint ./charts/elasticsearch
```
