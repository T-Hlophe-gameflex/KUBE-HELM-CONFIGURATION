#!/bin/bash
set -euo pipefail

echo "🚀 Deploying ELK Stack - Please don't interrupt!"
echo "This will take 5-10 minutes..."
echo ""

# Deploy Elasticsearch
echo "📦 Deploying Elasticsearch (1/3)..."
helm install elasticsearch elastic/elasticsearch \
  --namespace monitoring \
  --set replicas=1 \
  --set resources.requests.memory=1Gi \
  --set resources.limits.memory=2Gi \
  --set persistence.enabled=false \
  --wait --timeout=5m > /tmp/es-deploy.log 2>&1 &
ES_PID=$!

wait $ES_PID
if [ $? -eq 0 ]; then
    echo "✅ Elasticsearch deployed"
else
    echo "❌ Elasticsearch failed - check /tmp/es-deploy.log"
    exit 1
fi

# Deploy Kibana
echo "📦 Deploying Kibana (2/3)..."
helm install kibana elastic/kibana \
  --namespace monitoring \
  --set service.type=NodePort \
  --set service.nodePort=30601 \
  --wait --timeout=5m > /tmp/kibana-deploy.log 2>&1 &
KIBANA_PID=$!

wait $KIBANA_PID
if [ $? -eq 0 ]; then
    echo "✅ Kibana deployed"
else
    echo "❌ Kibana failed - check /tmp/kibana-deploy.log"
    exit 1
fi

# Deploy Filebeat
echo "📦 Deploying Filebeat (3/3)..."
helm install filebeat elastic/filebeat \
  --namespace monitoring \
  --set daemonset.enabled=true \
  --wait --timeout=5m > /tmp/filebeat-deploy.log 2>&1 &
FILEBEAT_PID=$!

wait $FILEBEAT_PID
if [ $? -eq 0 ]; then
    echo "✅ Filebeat deployed"
else
    echo "❌ Filebeat failed - check /tmp/filebeat-deploy.log"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ELK Stack deployed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔗 Access Kibana:"
echo "   kubectl port-forward -n monitoring svc/kibana-kibana 5601:5601"
echo "   Then open: http://localhost:5601"
echo ""
echo "📊 Check status:"
echo "   kubectl get pods -n monitoring"
echo ""
