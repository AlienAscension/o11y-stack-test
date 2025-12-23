#!/bin/bash

# Script to verify logs in OpenSearch

NAMESPACE="observability-opensearch"
SERVICE="opensearch-cluster"
USERNAME="admin"
PASSWORD="1ihL2fm6aFo2S1dxuDRzfD"
INDEX_NAME="${1:-test-logs-2025.12.22}"

echo "Setting up port-forward to OpenSearch service..."
kubectl port-forward -n $NAMESPACE svc/$SERVICE 9200:9200 &
PF_PID=$!

# Wait for port-forward to be ready
sleep 3

echo "Refreshing index: $INDEX_NAME"
curl -k -X POST "https://localhost:9200/$INDEX_NAME/_refresh" \
  -u "$USERNAME:$PASSWORD" 2>/dev/null

echo -e "\n\nQuerying logs from index: $INDEX_NAME"
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
  "size": 10
}'

echo -e "\n\nIndex stats:"
curl -k -X GET "https://localhost:9200/$INDEX_NAME/_stats?pretty" \
  -u "$USERNAME:$PASSWORD" 2>/dev/null | grep -A 5 '"docs"'

echo -e "\n\nAll indices:"
curl -k -X GET "https://localhost:9200/_cat/indices?v" \
  -u "$USERNAME:$PASSWORD" 2>/dev/null

# Cleanup
echo -e "\n\nCleaning up port-forward..."
kill $PF_PID 2>/dev/null
wait $PF_PID 2>/dev/null

echo "Done!"
