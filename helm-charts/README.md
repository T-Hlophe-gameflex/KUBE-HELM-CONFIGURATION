# ELK Stack & Infrastructure Helm Charts

Helm charts for deploying ELK Stack with microservices, AWX automation platform, and Cloudflare DNS management.

## Charts Structure

```text
charts/
├── elasticsearch/     # Search and analytics engine
├── kibana/           # Data visualization interface  
├── logstash/         # Log processing pipeline
├── filebeat/         # Log data collector
├── metallb/          # Load balancer configuration
├── awx/              # Ansible AWX automation platform
├── cloudflare/       # Cloudflare DNS management
└── services/         # Application services
    ├── order-service/   # Order management API
    ├── user-service/    # User management API
    └── postgres/        # PostgreSQL database
```

## Deployment

### ELK Stack Components
```bash
helm upgrade --install elasticsearch ./charts/elasticsearch -n monitoring --create-namespace
helm upgrade --install kibana ./charts/kibana -n monitoring
helm upgrade --install logstash ./charts/logstash -n monitoring
helm upgrade --install filebeat ./charts/filebeat -n monitoring
```

### Infrastructure & Automation
```bash
# Load balancer
helm upgrade --install metallb ./charts/metallb -n metallb-system --create-namespace

# AWX automation platform
helm upgrade --install awx ./charts/awx -n awx --create-namespace

# Cloudflare DNS automation
helm upgrade --install cloudflare ./charts/cloudflare -n dns-automation --create-namespace
```

### Application Services
```bash
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

**AWX** (`charts/awx/values.yaml`)
- `awx.serviceType`: Service type (default: nodeport)
- `awx.nodePort`: NodePort for AWX access (default: 30080)
- `postgres.storage.size`: PostgreSQL storage size (default: 10Gi)
- `postgres.storage.hostPath`: Local storage path (default: /mnt/awx-storage)
- `awx.admin.email`: Admin user email
- `awx.admin.password`: Admin user password (auto-generated if empty)

**Cloudflare** (`charts/cloudflare/values.yaml`)
- `cloudflare.apiToken`: Cloudflare API token for authentication
- `cloudflare.domain`: Target domain for DNS operations
- `cloudflare.dnsRecords`: Array of DNS records to manage
- `job.schedule`: Cron schedule for recurring operations (optional)
- `ansible.image`: Ansible execution environment image

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

# AWX Web Interface
kubectl get svc -n awx
# Access via NodePort (default: http://<node-ip>:30080)
# Username: admin, Password: retrieve using:
kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode

# Order Service
kubectl port-forward -n backend svc/order-service 8080:8080

# User Service
kubectl port-forward -n backend svc/user-service 8081:8081

# PostgreSQL
kubectl port-forward -n database svc/postgres 5432:5432
```

## AWX Integration Features

### Cloudflare DNS Management
- **Dynamic Surveys**: Web-based forms for DNS operations
- **Domain Selection**: Dropdown list of managed domains
- **Record Types**: Support for A, AAAA, CNAME, MX, TXT, SRV, CAA
- **Bulk Operations**: JSON-based multiple record creation
- **Proxy Control**: Toggle Cloudflare orange cloud protection

### Job Templates Available
1. **Cloudflare DNS Management**: Full DNS record CRUD operations
2. **Cloudflare Zone Info**: Zone inspection and record listing

### Survey Features
- Domain dropdown (customizable)
- Operation selection (create/update/delete/bulk/list)
- Record configuration (name, type, value, TTL)
- Cloudflare proxy toggle
- Bulk record JSON input

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
