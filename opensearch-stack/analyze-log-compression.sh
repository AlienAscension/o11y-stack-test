#!/bin/bash

# OpenSearch Log Compression Analysis Script
# Analyzes the ss4o_logs-otel-demo-default index for compression ratio

set -e

# Configuration
OPENSEARCH_URL="https://localhost:9200"
OPENSEARCH_USER="admin"
OPENSEARCH_PASS="${OPENSEARCH_PASSWORD:-1ihL2fm6aFo2S1dxuDRzfD}"
INDEX_NAME="ss4o_logs-otel-demo-default"
SAMPLE_SIZE="${SAMPLE_SIZE:-1000}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   OpenSearch Log Compression Analysis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if OpenSearch is accessible
echo -e "${YELLOW}Checking OpenSearch connection...${NC}"
if ! curl -k -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" "${OPENSEARCH_URL}/_cluster/health" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to OpenSearch at ${OPENSEARCH_URL}${NC}"
    echo "Please ensure:"
    echo "  1. OpenSearch is running"
    echo "  2. Port-forward is active: kubectl port-forward -n observability-opensearch svc/opensearch-cluster 9200:9200"
    echo "  3. Credentials are correct"
    exit 1
fi
echo -e "${GREEN}✓ Connected to OpenSearch${NC}"
echo ""

# Get index statistics
echo -e "${YELLOW}Fetching index statistics...${NC}"
INDEX_STATS=$(curl -k -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" "${OPENSEARCH_URL}/${INDEX_NAME}/_stats" | jq ".indices[\"${INDEX_NAME}\"].total")

TOTAL_DOCS=$(echo "$INDEX_STATS" | jq -r '.docs.count')
DELETED_DOCS=$(echo "$INDEX_STATS" | jq -r '.docs.deleted')
STORE_SIZE_BYTES=$(echo "$INDEX_STATS" | jq -r '.store.size_in_bytes')
STORE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $STORE_SIZE_BYTES / 1024 / 1024}")
SEGMENT_COUNT=$(echo "$INDEX_STATS" | jq -r '.segments.count')

echo -e "${GREEN}✓ Index statistics retrieved${NC}"
echo ""

# Sample documents to estimate uncompressed size
echo -e "${YELLOW}Sampling ${SAMPLE_SIZE} documents to estimate uncompressed size...${NC}"
SAMPLE_DATA=$(curl -k -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" "${OPENSEARCH_URL}/${INDEX_NAME}/_search?size=${SAMPLE_SIZE}" | \
  jq '{
    sample_size: (.hits.hits | length),
    total_json_bytes: ([.hits.hits[]._source | tostring | length] | add),
    avg_json_size_bytes: (([.hits.hits[]._source | tostring | length] | add) / (.hits.hits | length))
  }')

SAMPLE_SIZE_ACTUAL=$(echo "$SAMPLE_DATA" | jq -r '.sample_size')
AVG_JSON_SIZE=$(echo "$SAMPLE_DATA" | jq -r '.avg_json_size_bytes')

# Calculate estimated uncompressed size
ESTIMATED_UNCOMPRESSED_BYTES=$(awk "BEGIN {printf \"%.2f\", $AVG_JSON_SIZE * $TOTAL_DOCS}")
ESTIMATED_UNCOMPRESSED_MB=$(awk "BEGIN {printf \"%.2f\", $ESTIMATED_UNCOMPRESSED_BYTES / 1024 / 1024}")

# Calculate compression ratio
COMPRESSION_RATIO=$(awk "BEGIN {printf \"%.2f\", $ESTIMATED_UNCOMPRESSED_MB / $STORE_SIZE_MB}")
SPACE_SAVED_MB=$(awk "BEGIN {printf \"%.2f\", $ESTIMATED_UNCOMPRESSED_MB - $STORE_SIZE_MB}")
SPACE_SAVED_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($SPACE_SAVED_MB / $ESTIMATED_UNCOMPRESSED_MB) * 100}")

echo -e "${GREEN}✓ Compression analysis complete${NC}"
echo ""

# Display results
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Results${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Index Information:${NC}"
echo "  Index Name:           ${INDEX_NAME}"
echo "  Total Documents:      $(printf "%'d" $TOTAL_DOCS)"
echo "  Deleted Documents:    $(printf "%'d" $DELETED_DOCS)"
echo "  Segment Count:        ${SEGMENT_COUNT}"
echo ""
echo -e "${YELLOW}Storage Analysis:${NC}"
echo "  Stored Size:          ${STORE_SIZE_MB} MB"
echo "  Avg Doc Size (disk):  $(awk "BEGIN {printf \"%.2f\", $STORE_SIZE_BYTES / $TOTAL_DOCS}") bytes"
echo ""
echo -e "${YELLOW}Uncompressed Estimate (based on ${SAMPLE_SIZE_ACTUAL} sample docs):${NC}"
echo "  Avg JSON Size:        $(LC_NUMERIC=C printf "%.2f" $AVG_JSON_SIZE) bytes"
echo "  Est. Total Size:      ${ESTIMATED_UNCOMPRESSED_MB} MB"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Compression Results${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Compression Ratio:    ${GREEN}${COMPRESSION_RATIO}:1${NC}"
echo -e "  Space Saved:          ${GREEN}${SPACE_SAVED_MB} MB${NC} (${SPACE_SAVED_PERCENT}%)"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Additional insights
echo -e "${YELLOW}Analysis Notes:${NC}"
echo "  • Compression ratio calculated from sample of ${SAMPLE_SIZE_ACTUAL} documents"
echo "  • OpenSearch uses LZ4 compression by default for stored fields"
echo "  • Actual compression may vary based on log content patterns"
echo "  • Additional space used by indices, mappings, and metadata not included"
echo ""

# Export to CSV if requested
if [ "$EXPORT_CSV" = "true" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CSV_FILE="opensearch-compression-${TIMESTAMP}.csv"
    echo "timestamp,index_name,total_docs,store_size_mb,estimated_uncompressed_mb,compression_ratio,space_saved_mb,space_saved_percent" > "$CSV_FILE"
    echo "$(date -Iseconds),${INDEX_NAME},${TOTAL_DOCS},${STORE_SIZE_MB},${ESTIMATED_UNCOMPRESSED_MB},${COMPRESSION_RATIO},${SPACE_SAVED_MB},${SPACE_SAVED_PERCENT}" >> "$CSV_FILE"
    echo -e "${GREEN}✓ Results exported to: ${CSV_FILE}${NC}"
    echo ""
fi
