#!/bin/bash

# Loki Log Compression Analysis Script
# Analyzes Loki storage for compression ratio

set -e

# Configuration
LOKI_URL="${LOKI_URL:-http://localhost:3100}"
# Loki uses label matchers for queries
LABEL_FILTER="${LABEL_FILTER:-{namespace=\"otel-demo\"}}"
SAMPLE_SIZE="${SAMPLE_SIZE:-1000}"
TIME_RANGE="${TIME_RANGE:-48h}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Loki Log Compression Analysis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if Loki is accessible
echo -e "${YELLOW}Checking Loki connection...${NC}"
if ! curl -s "${LOKI_URL}/ready" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to Loki at ${LOKI_URL}${NC}"
    echo "Please ensure:"
    echo "  1. Loki is running"
    echo "  2. Port-forward is active: kubectl port-forward -n observability-lgtm svc/loki 3100:3100"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Loki${NC}"
echo ""

# Get storage statistics from Loki metrics
echo -e "${YELLOW}Fetching storage statistics...${NC}"
METRICS=$(curl -s "${LOKI_URL}/metrics")

# Extract relevant metrics
# Loki stores metrics about ingested bytes and lines
INGESTED_BYTES=$(echo "$METRICS" | grep '^loki_distributor_bytes_received_total' | awk '{sum+=$2} END {print sum}')
INGESTED_LINES=$(echo "$METRICS" | grep '^loki_distributor_lines_received_total' | awk '{sum+=$2} END {print sum}')

# Get chunk store metrics
CHUNKS_CREATED=$(echo "$METRICS" | grep '^loki_ingester_chunks_created_total' | awk '{sum+=$2} END {print sum}')
CHUNKS_STORED=$(echo "$METRICS" | grep '^loki_ingester_chunks_stored_total' | awk '{sum+=$2} END {print sum}')

# Get actual stored chunk bytes from metrics (most accurate)
CHUNK_BYTES_STORED=$(echo "$METRICS" | grep '^loki_chunk_store_stored_chunk_bytes_total' | awk '{sum+=$2} END {print sum}')
if [ -z "$CHUNK_BYTES_STORED" ] || [ "$CHUNK_BYTES_STORED" = "0" ]; then
    CHUNK_BYTES_STORED=$(echo "$METRICS" | grep '^loki_ingester_chunk_size_bytes_sum' | awk '{print $2}' | head -1)
fi

# Try to get actual storage size from pod (includes index and metadata)
POD_NAME="${LOKI_POD:-$(timeout 5 kubectl get pods -n observability-lgtm -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)}"
STORAGE_SIZE=""
if [ -n "$POD_NAME" ]; then
    echo -e "${YELLOW}Attempting to fetch storage size from pod ${POD_NAME}...${NC}"
    # Try to get storage size (du might not be available in minimal images)
    STORAGE_SIZE=$(timeout 5 kubectl exec -n observability-lgtm "$POD_NAME" -c loki -- du -sb /var/loki 2>/dev/null | awk '{print $1}')
fi

# Use chunk bytes as the primary storage metric (this is the actual compressed data)
if [ -z "$STORAGE_SIZE" ] || [ "$STORAGE_SIZE" = "0" ]; then
    echo -e "${YELLOW}Using chunk metrics for storage size...${NC}"
    STORAGE_SIZE=$CHUNK_BYTES_STORED
    # Add estimation for index overhead (typically 10-20% of chunk data)
    INDEX_OVERHEAD=$(awk "BEGIN {printf \"%.0f\", $CHUNK_BYTES_STORED * 0.15}")
    STORAGE_SIZE=$(awk "BEGIN {printf \"%.0f\", $STORAGE_SIZE + $INDEX_OVERHEAD}")
fi

# Ensure we have valid values
if [ -z "$INGESTED_BYTES" ] || [ "$INGESTED_BYTES" = "0" ]; then
    INGESTED_BYTES=0
fi
if [ -z "$INGESTED_LINES" ] || [ "$INGESTED_LINES" = "0" ]; then
    INGESTED_LINES=0
fi

# Calculate sizes in MB
STORE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $STORAGE_SIZE / 1024 / 1024}")

echo -e "${GREEN}✓ Storage statistics retrieved${NC}"
echo ""

# Query logs to get document count and estimate size
echo -e "${YELLOW}Querying logs for compression analysis...${NC}"
QUERY_URL="${LOKI_URL}/loki/api/v1/query_range"

# Sample documents to estimate uncompressed size
echo -e "${YELLOW}Sampling ${SAMPLE_SIZE} log entries to estimate uncompressed size...${NC}"

# Calculate time range in nanoseconds
NOW=$(date +%s)000000000
START=$((NOW - 48*3600*1000000000))  # 48 hours ago

# Loki returns NDJSON format with streams
SAMPLE_RESPONSE=$(curl -s -G "${QUERY_URL}" \
  --data-urlencode "query=${LABEL_FILTER}" \
  --data-urlencode "start=${START}" \
  --data-urlencode "end=${NOW}" \
  --data-urlencode "limit=${SAMPLE_SIZE}")

# Calculate JSON size of sample
SAMPLE_JSON_SIZE=$(echo "$SAMPLE_RESPONSE" | wc -c)

# Parse the response to count log entries
# Loki returns data in format: {"status":"success","data":{"resultType":"streams","result":[{"stream":{...},"values":[[timestamp,line],...]}]}}
SAMPLE_COUNT=$(echo "$SAMPLE_RESPONSE" | jq -r '.data.result[]?.values | length' 2>/dev/null | awk '{sum+=$1} END {print sum}')

# Use metrics to get total document count
TOTAL_DOCS=${INGESTED_LINES:-0}

if [ -z "$SAMPLE_COUNT" ] || [ "$SAMPLE_COUNT" = "0" ]; then
    echo -e "${RED}Warning: Could not retrieve sample data. Using fallback estimation.${NC}"
    # Fallback: assume average log entry size
    SAMPLE_COUNT=$SAMPLE_SIZE
    AVG_JSON_SIZE=500  # Conservative estimate for a log entry
else
    # Calculate average size from the JSON response
    # Note: This includes Loki's metadata overhead
    AVG_JSON_SIZE=$(awk "BEGIN {printf \"%.2f\", $SAMPLE_JSON_SIZE / $SAMPLE_COUNT}")
fi

# Calculate estimated uncompressed size
if [ "$TOTAL_DOCS" != "0" ] && [ -n "$TOTAL_DOCS" ]; then
    ESTIMATED_UNCOMPRESSED_BYTES=$(awk "BEGIN {printf \"%.2f\", $AVG_JSON_SIZE * $TOTAL_DOCS}")
    ESTIMATED_UNCOMPRESSED_MB=$(awk "BEGIN {printf \"%.2f\", $ESTIMATED_UNCOMPRESSED_BYTES / 1024 / 1024}")
    
    # Calculate compression ratio
    if awk "BEGIN {exit !($STORE_SIZE_MB > 0)}"; then
        COMPRESSION_RATIO=$(awk "BEGIN {printf \"%.2f\", $ESTIMATED_UNCOMPRESSED_MB / $STORE_SIZE_MB}")
        SPACE_SAVED_MB=$(awk "BEGIN {printf \"%.2f\", $ESTIMATED_UNCOMPRESSED_MB - $STORE_SIZE_MB}")
        SPACE_SAVED_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($SPACE_SAVED_MB / $ESTIMATED_UNCOMPRESSED_MB) * 100}")
    else
        COMPRESSION_RATIO="N/A"
        SPACE_SAVED_MB="N/A"
        SPACE_SAVED_PERCENT="N/A"
    fi
else
    ESTIMATED_UNCOMPRESSED_MB="N/A"
    COMPRESSION_RATIO="N/A"
    SPACE_SAVED_MB="N/A"
    SPACE_SAVED_PERCENT="N/A"
fi

echo -e "${GREEN}✓ Compression analysis complete${NC}"
echo ""

# Display results
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Results${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Storage Information:${NC}"
echo "  Label Filter:         ${LABEL_FILTER}"
echo "  Time Range:           ${TIME_RANGE}"
echo "  Total Log Lines:      $(printf "%'d" $TOTAL_DOCS 2>/dev/null || echo $TOTAL_DOCS)"
echo "  Bytes Ingested:       $(printf "%'d" $INGESTED_BYTES 2>/dev/null || echo $INGESTED_BYTES)"
echo "  Chunks Created:       $(printf "%'d" $CHUNKS_CREATED 2>/dev/null || echo ${CHUNKS_CREATED:-N/A})"
echo ""
echo -e "${YELLOW}Storage Analysis:${NC}"
echo "  Stored Size:          ${STORE_SIZE_MB} MB"
if [ "$TOTAL_DOCS" != "0" ] && [ -n "$STORAGE_SIZE" ] && [ "$TOTAL_DOCS" != "0" ]; then
    echo "  Avg Log Size (disk):  $(awk "BEGIN {printf \"%.2f\", $STORAGE_SIZE / $TOTAL_DOCS}") bytes"
fi
echo ""
echo -e "${YELLOW}Uncompressed Estimate (based on ${SAMPLE_COUNT:-0} sample docs):${NC}"
echo "  Avg JSON Size:        $(LC_NUMERIC=C printf "%.2f" ${AVG_JSON_SIZE:-0}) bytes"
echo "  Est. Total Size:      ${ESTIMATED_UNCOMPRESSED_MB} MB"
echo ""

if [ "$COMPRESSION_RATIO" != "N/A" ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Compression Results${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Compression Ratio:    ${GREEN}${COMPRESSION_RATIO}:1${NC}"
    echo -e "  Space Saved:          ${GREEN}${SPACE_SAVED_MB} MB${NC} (${SPACE_SAVED_PERCENT}%)"
    echo ""
fi
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Additional insights
echo -e "${YELLOW}Analysis Notes:${NC}"
echo "  • Compression ratio calculated from sample of ${SAMPLE_COUNT:-0} log entries"
echo "  • Loki uses Snappy compression for chunks by default"
echo "  • Actual compression may vary based on log content patterns"
echo "  • Loki also uses chunking and efficient indexing"
echo "  • Index and metadata storage not included in compression ratio"
echo ""

# Export to CSV if requested
if [ "$EXPORT_CSV" = "true" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CSV_FILE="loki-compression-${TIMESTAMP}.csv"
    echo "timestamp,label_filter,time_range,total_docs,store_size_mb,estimated_uncompressed_mb,compression_ratio,space_saved_mb,space_saved_percent" > "$CSV_FILE"
    echo "$(date -Iseconds),${LABEL_FILTER},${TIME_RANGE},${TOTAL_DOCS},${STORE_SIZE_MB},${ESTIMATED_UNCOMPRESSED_MB},${COMPRESSION_RATIO},${SPACE_SAVED_MB},${SPACE_SAVED_PERCENT}" >> "$CSV_FILE"
    echo -e "${GREEN}✓ Results exported to: ${CSV_FILE}${NC}"
    echo ""
fi
