#!/bin/bash

# VictoriaLogs Compression Analysis Script
# Analyzes VictoriaLogs storage for compression ratio

set -e

# Configuration
VLOGS_URL="${VLOGS_URL:-http://localhost:9428}"
# VictoriaLogs stores logs in streams, typically identified by tenant/project
STREAM_FILTER="${STREAM_FILTER:-{k8s.namespace.name=\"otel-demo\"}}"
SAMPLE_SIZE="${SAMPLE_SIZE:-1000}"
TIME_RANGE="${TIME_RANGE:-24h}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   VictoriaLogs Compression Analysis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if VictoriaLogs is accessible
echo -e "${YELLOW}Checking VictoriaLogs connection...${NC}"
if ! curl -s "${VLOGS_URL}/health" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to VictoriaLogs at ${VLOGS_URL}${NC}"
    echo "Please ensure:"
    echo "  1. VictoriaLogs is running"
    echo "  2. Port-forward is active: kubectl port-forward -n observability-victoriametrics svc/victorialogs 9428:9428"
    exit 1
fi
echo -e "${GREEN}✓ Connected to VictoriaLogs${NC}"
echo ""

# Get storage statistics from VictoriaLogs metrics
echo -e "${YELLOW}Fetching storage statistics...${NC}"
METRICS=$(curl -s "${VLOGS_URL}/metrics")

# Extract relevant metrics
TOTAL_ROWS=$(echo "$METRICS" | grep '^vl_rows_ingested_total' | head -1 | awk '{print $2}')
BYTES_INGESTED=$(echo "$METRICS" | grep '^vl_bytes_ingested_total' | head -1 | awk '{print $2}')

# Try to get actual storage size from pod (with timeout)
POD_NAME="${VLOGS_POD:-$(timeout 5 kubectl get pods -n victoriametrics -l app.kubernetes.io/name=victorialogs -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)}"
STORAGE_SIZE=""
if [ -n "$POD_NAME" ]; then
    echo -e "${YELLOW}Fetching actual storage size from pod ${POD_NAME}...${NC}"
    STORAGE_SIZE=$(timeout 5 kubectl exec -n victoriametrics "$POD_NAME" -- du -sb /vlogs-data 2>/dev/null | awk '{print $1}')
fi

# Fallback: estimate from metrics  
if [ -z "$STORAGE_SIZE" ] || [ "$STORAGE_SIZE" = "0" ]; then
    echo -e "${YELLOW}Using metrics-based estimation for storage size...${NC}"
    STORAGE_SIZE=$(echo "$METRICS" | grep '^vl_merge_bytes_sum' | awk '{print $2}' | head -1)
fi

# Last fallback: use ingested bytes as upper bound
if [ -z "$STORAGE_SIZE" ] || [ "$STORAGE_SIZE" = "0" ]; then
    STORAGE_SIZE=$BYTES_INGESTED
fi

# Calculate sizes in MB
STORE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $STORAGE_SIZE / 1024 / 1024}")

echo -e "${GREEN}✓ Storage statistics retrieved${NC}"
echo ""

# Query logs to get document count and estimate size
echo -e "${YELLOW}Querying logs for compression analysis...${NC}"
QUERY_URL="${VLOGS_URL}/select/logsql/query"

# Sample documents to estimate uncompressed size
echo -e "${YELLOW}Sampling ${SAMPLE_SIZE} log entries to estimate uncompressed size...${NC}"

# VictoriaLogs returns NDJSON (newline-delimited JSON) format
SAMPLE_RESPONSE=$(curl -s -d "query=${STREAM_FILTER} | limit ${SAMPLE_SIZE}" "${QUERY_URL}")

# Calculate JSON size of sample and count
SAMPLE_JSON_SIZE=$(echo "$SAMPLE_RESPONSE" | wc -c)
SAMPLE_COUNT=$(echo "$SAMPLE_RESPONSE" | grep -c '^{' 2>/dev/null || echo "0")

# Use metrics to get total document count
TOTAL_DOCS=${TOTAL_ROWS:-0}

if [ "$SAMPLE_COUNT" = "0" ] || [ -z "$SAMPLE_COUNT" ]; then
    echo -e "${RED}Warning: Could not retrieve sample data. Using fallback estimation.${NC}"
    # Fallback: assume average log entry size
    SAMPLE_COUNT=$SAMPLE_SIZE
    AVG_JSON_SIZE=500  # Conservative estimate for a log entry
else
    AVG_JSON_SIZE=$(awk "BEGIN {printf \"%.2f\", $SAMPLE_JSON_SIZE / $SAMPLE_COUNT}")
fi

# Calculate estimated uncompressed size
if [ "$TOTAL_DOCS" != "0" ]; then
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
echo "  Stream Filter:        ${STREAM_FILTER}"
echo "  Time Range:           ${TIME_RANGE}"
echo "  Total Log Entries:    $(printf "%'d" $TOTAL_DOCS 2>/dev/null || echo $TOTAL_DOCS)"
echo "  Bytes Ingested:       $(printf "%'d" $BYTES_INGESTED 2>/dev/null || echo $BYTES_INGESTED)"
echo ""
echo -e "${YELLOW}Storage Analysis:${NC}"
echo "  Stored Size:          ${STORE_SIZE_MB} MB"
if [ "$TOTAL_DOCS" != "0" ] && [ -n "$STORAGE_SIZE" ]; then
    echo "  Avg Doc Size (disk):  $(awk "BEGIN {printf \"%.2f\", $STORAGE_SIZE / $TOTAL_DOCS}") bytes"
fi
echo ""
echo -e "${YELLOW}Uncompressed Estimate (based on ${SAMPLE_COUNT} sample docs):${NC}"
echo "  Avg JSON Size:        $(LC_NUMERIC=C printf "%.2f" $AVG_JSON_SIZE) bytes"
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
echo "  • Compression ratio calculated from sample of ${SAMPLE_COUNT} log entries"
echo "  • VictoriaLogs uses zstd compression for storage by default"
echo "  • Actual compression may vary based on log content patterns"
echo "  • VictoriaLogs also uses deduplication and efficient encoding"
echo "  • Time-series metadata and indexes consume additional space"
echo ""

# Export to CSV if requested
if [ "$EXPORT_CSV" = "true" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CSV_FILE="victorialogs-compression-${TIMESTAMP}.csv"
    echo "timestamp,stream_filter,time_range,total_docs,store_size_mb,estimated_uncompressed_mb,compression_ratio,space_saved_mb,space_saved_percent" > "$CSV_FILE"
    echo "$(date -Iseconds),${STREAM_FILTER},${TIME_RANGE},${TOTAL_DOCS},${STORE_SIZE_MB},${ESTIMATED_UNCOMPRESSED_MB},${COMPRESSION_RATIO},${SPACE_SAVED_MB},${SPACE_SAVED_PERCENT}" >> "$CSV_FILE"
    echo -e "${GREEN}✓ Results exported to: ${CSV_FILE}${NC}"
    echo ""
fi
