#!/bin/bash

# Generate sample logs for Kibana visualization
# Usage: ./generate-sample-logs.sh [number_of_entries]

ENTRIES=${1:-50}
SERVICES=("user-service" "order-service" "payment-service" "notification-service" "inventory-service")
LEVELS=("info" "warn" "error" "debug")
NAMESPACES=("default" "monitoring" "backend" "frontend")
METHODS=("GET" "POST" "PUT" "DELETE" "PATCH")
ENDPOINTS=("/api/users" "/api/orders" "/api/products" "/api/payments" "/api/inventory")

echo "=========================================="
echo "Generating $ENTRIES realistic log entries"
echo "=========================================="
echo ""

ES_URL="http://localhost:9200"

# Check if port-forward to Elasticsearch is needed
if ! curl -s "$ES_URL" > /dev/null 2>&1; then
    echo "Starting port-forward to Elasticsearch..."
    kubectl port-forward -n monitoring svc/elk-stack-platform-elasticsearch 9200:9200 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 2
fi

for i in $(seq 1 $ENTRIES); do
    SERVICE=${SERVICES[$((RANDOM % ${#SERVICES[@]}))]}
    LEVEL=${LEVELS[$((RANDOM % ${#LEVELS[@]}))]}
    NAMESPACE=${NAMESPACES[$((RANDOM % ${#NAMESPACES[@]}))]}
    METHOD=${METHODS[$((RANDOM % ${#METHODS[@]}))]}
    ENDPOINT=${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}
    
    # Vary response times based on level
    if [ "$LEVEL" == "error" ]; then
        RESPONSE_TIME=$((RANDOM % 2000 + 1000))  # Errors are slower
        STATUS_CODE=$((RANDOM % 100 + 500))       # 500-599
    elif [ "$LEVEL" == "warn" ]; then
        RESPONSE_TIME=$((RANDOM % 1000 + 500))
        STATUS_CODE=$((RANDOM % 100 + 400))       # 400-499
    else
        RESPONSE_TIME=$((RANDOM % 300 + 50))
        STATUS_CODE=$((RANDOM % 100 + 200))       # 200-299
    fi
    
    AMOUNT=$((RANDOM % 2000 + 10))
    TRACE_ID="trace-$(openssl rand -hex 8)"
    SPAN_ID="span-$(openssl rand -hex 4)"
    
    # Generate realistic messages based on service and level
    case $SERVICE in
        "user-service")
            if [ "$LEVEL" == "error" ]; then
                MESSAGES=("User authentication failed" "Database connection timeout" "Invalid credentials provided" "Session token expired")
            elif [ "$LEVEL" == "warn" ]; then
                MESSAGES=("User login attempt from new location" "Password reset requested" "Multiple failed login attempts" "Session about to expire")
            else
                MESSAGES=("User login successful" "User profile updated" "User registered successfully" "User session created")
            fi
            ;;
        "order-service")
            if [ "$LEVEL" == "error" ]; then
                MESSAGES=("Failed to create order - inventory unavailable" "Payment processing failed" "Order database write error" "Invalid order data")
            elif [ "$LEVEL" == "warn" ]; then
                MESSAGES=("Low inventory for requested items" "Order processing delayed" "Payment gateway slow response" "Order requires manual review")
            else
                MESSAGES=("Order created successfully" "Order payment processed" "Order shipped to customer" "Order completed")
            fi
            ;;
        "payment-service")
            if [ "$LEVEL" == "error" ]; then
                MESSAGES=("Payment gateway timeout" "Card declined by issuer" "Fraud detection triggered" "Payment processing exception")
            elif [ "$LEVEL" == "warn" ]; then
                MESSAGES=("Payment retry attempted" "High-value transaction flagged" "Payment gateway response slow" "Insufficient funds")
            else
                MESSAGES=("Payment authorized successfully" "Refund processed" "Payment captured" "Transaction completed")
            fi
            ;;
        "notification-service")
            if [ "$LEVEL" == "error" ]; then
                MESSAGES=("Failed to send email - SMTP error" "SMS gateway unavailable" "Push notification service down" "Message queue connection lost")
            elif [ "$LEVEL" == "warn" ]; then
                MESSAGES=("Email delivery delayed" "SMS rate limit approaching" "Notification retry scheduled" "Template rendering slow")
            else
                MESSAGES=("Email sent successfully" "SMS delivered" "Push notification sent" "Notification queued")
            fi
            ;;
        "inventory-service")
            if [ "$LEVEL" == "error" ]; then
                MESSAGES=("Inventory sync failed" "Database deadlock detected" "SKU not found in system" "Stock update failed")
            elif [ "$LEVEL" == "warn" ]; then
                MESSAGES=("Low stock alert" "Inventory threshold reached" "Stock discrepancy detected" "Reorder point triggered")
            else
                MESSAGES=("Inventory updated successfully" "Stock level synchronized" "Product availability checked" "Inventory record created")
            fi
            ;;
    esac
    
    MESSAGE=${MESSAGES[$((RANDOM % ${#MESSAGES[@]}))]}
    
    # Determine which index to use based on service
    if [[ "$SERVICE" == "order-service" ]]; then
        INDEX="order-service-logs-$(date +%Y.%m.%d)"
    elif [[ "$SERVICE" == "user-service" ]]; then
        INDEX="user-service-logs-$(date +%Y.%m.%d)"
    else
        INDEX="kubespray-logs-$(date +%Y.%m.%d)"
    fi
    
    # Create log entry with rich fields
    curl -s -X POST "$ES_URL/$INDEX/_doc" \
        -H 'Content-Type: application/json' \
        -d "{
            \"@timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
            \"level\": \"$LEVEL\",
            \"message\": \"$MESSAGE\",
            \"service\": \"$SERVICE\",
            \"environment\": \"production\",
            \"host\": {
                \"name\": \"$SERVICE-$(openssl rand -hex 4)\"
            },
            \"kubernetes\": {
                \"namespace\": \"$NAMESPACE\",
                \"pod\": \"$SERVICE-$(openssl rand -hex 4)-$(openssl rand -hex 4)\",
                \"container\": \"$SERVICE\"
            },
            \"trace_id\": \"$TRACE_ID\",
            \"span_id\": \"$SPAN_ID\",
            \"http\": {
                \"method\": \"$METHOD\",
                \"url\": \"$ENDPOINT\",
                \"status_code\": $STATUS_CODE,
                \"request_id\": \"req-$(openssl rand -hex 6)\"
            },
            \"user\": {
                \"id\": \"user-$((RANDOM % 1000))\"
            },
            \"performance\": {
                \"duration_ms\": $RESPONSE_TIME
            },
            \"business\": {
                \"amount\": $AMOUNT,
                \"currency\": \"USD\"
            }
        }" > /dev/null
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "✓ Generated $i/$ENTRIES entries..."
    fi
    
    # Small delay to spread timestamps
    sleep 0.05
done

# Kill port-forward if we started it
if [ ! -z "$PF_PID" ]; then
    kill $PF_PID 2>/dev/null
fi

echo ""
echo "=========================================="
echo "✅ Generated $ENTRIES log entries!"
echo "=========================================="
echo ""
echo "📊 Log Distribution:"
curl -s "$ES_URL/*-logs-*/_search?size=0&pretty" \
    -H 'Content-Type: application/json' \
    -d '{
        "aggs": {
            "by_service": {"terms": {"field": "service", "size": 10}},
            "by_level": {"terms": {"field": "level", "size": 10}}
        }
    }' | jq -r '
    .aggregations.by_service.buckets[] | "  - \(.key): \(.doc_count) logs"
'

echo ""
echo "📈 By Log Level:"
curl -s "$ES_URL/*-logs-*/_search?size=0&pretty" \
    -H 'Content-Type: application/json' \
    -d '{
        "aggs": {
            "by_level": {"terms": {"field": "level", "size": 10}}
        }
    }' | jq -r '
    .aggregations.by_level.buckets[] | "  - \(.key): \(.doc_count) logs"
'

echo ""
echo "🔍 View logs in Kibana:"
echo "  1. Access: http://localhost:5601"
echo "  2. Go to: Management → Stack Management → Data Views"
echo "  3. Create Data View with pattern: *-service-logs-*,kubespray-logs-*"
echo "  4. Set time field: @timestamp"
echo "  5. Go to: Analytics → Discover"
echo ""
echo "💡 Quick access Kibana:"
echo "   make kibana    # Start port-forward"
echo ""
echo "🔎 Query logs from terminal:"
echo "   curl \"http://localhost:9200/*-logs-*/_search?size=5&pretty\""
echo ""
