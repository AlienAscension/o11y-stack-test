#!/bin/bash

# Test script to write a log entry to OpenSearch
# This will port-forward to the OpenSearch service and send a test log

NAMESPACE="observability-opensearch"
SERVICE="opensearch-cluster"
USERNAME="admin"
PASSWORD="1ihL2fm6aFo2S1dxuDRzfD"
INDEX_NAME="test-logs-$(date +%Y.%m.%d)"

echo "Creating test log entry..."

# Create a test log document
LOG_ENTRY=$(cat <<EOF
{
  "@timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "level": "INFO",
  "message": "Test log entry from OpenSearch Stack test",
  "service": "test-service",
  "environment": "development",
  "host": "$(hostname)",
  "metadata": {
    "test_id": "$(uuidgen)",
    "source": "manual-test-script"
  }
}
EOF
)

echo "Setting up port-forward to OpenSearch service..."
kubectl port-forward -n $NAMESPACE svc/$SERVICE 9200:9200 &
PF_PID=$!

# Wait for port-forward to be ready
sleep 3

echo "Sending log entry to index: $INDEX_NAME"
curl -k -X POST "https://localhost:9200/$INDEX_NAME/_doc" \
  -u "$USERNAME:$PASSWORD" \
  -H 'Content-Type: application/json' \
  -d "$LOG_ENTRY"

echo -e "\n\nVerifying the log was written..."
curl -k -X GET "https://localhost:9200/$INDEX_NAME/_search?pretty" \
  -u "$USERNAME:$PASSWORD" \
  -H 'Content-Type: application/json' \
  -d '{
  "query": {
    "match_all": {}
  },
  "sort": [
    {
      "@timestamp": {
        "order": "desc"
      }
    }
  ],
  "size": 5
}'

# Cleanup
echo -e "\n\nCleaning up port-forward..."
kill $PF_PID 2>/dev/null
wait $PF_PID 2>/dev/null

echo "Done!"
