# Jaeger and Prometheus Deployment Guide

This guide describes how to deploy Jaeger with OpenSearch backend and Prometheus to your Kubernetes cluster.

## Prerequisites

- OpenSearch cluster is already running in the `observability-opensearch` namespace
- Helm 3 installed
- kubectl configured with cluster access
- Admin credentials configured via `admin-credentials-secret`

## Architecture

- **Jaeger**: Distributed tracing with OpenSearch as storage backend
  - Collector: Receives traces via OTLP (gRPC on 4317, HTTP on 4318)
  - Query: Provides Jaeger UI (port 16686)
  - Agent: Runs on each node to collect traces
- **Prometheus**: Metrics storage and querying
  - Remote write receiver enabled for OTLP metrics ingestion

## Installation Steps

### 1. Add Helm Repositories

```bash
# Add Jaeger Helm repository
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts

# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update repositories
helm repo update
```

### 2. Create Namespace (if not exists)

```bash
kubectl create namespace observability-opensearch --dry-run=client -o yaml | kubectl apply -f -
```

### 3. Verify OpenSearch is Running

```bash
kubectl get opensearchcluster -n observability-opensearch
kubectl get pods -n observability-opensearch
```

### 4. Deploy Jaeger

```bash
# Install Jaeger with OpenSearch backend
helm install jaeger jaegertracing/jaeger \
  --namespace observability-opensearch \
  --values jaeger-values.yaml \
  --wait
```

### 5. Deploy Prometheus

```bash
# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace observability-opensearch \
  --values prometheus-values.yaml \
  --wait
```

## Verification

### Check Jaeger

```bash
# Check Jaeger pods
kubectl get pods -n observability-opensearch -l app.kubernetes.io/instance=jaeger

# Check Jaeger services
kubectl get svc -n observability-opensearch -l app.kubernetes.io/instance=jaeger

# Port-forward to Jaeger UI
kubectl port-forward -n observability-opensearch svc/jaeger-query 16686:16686
# Access at: http://localhost:16686
```

### Check Prometheus

```bash
# Check Prometheus pods
kubectl get pods -n observability-opensearch -l app.kubernetes.io/instance=prometheus

# Check Prometheus services
kubectl get svc -n observability-opensearch -l app.kubernetes.io/instance=prometheus

# Port-forward to Prometheus UI
kubectl port-forward -n observability-opensearch svc/prometheus-server 9090:80
# Access at: http://localhost:9090
```

## Sending Test Traces

### Using OpenTelemetry Collector Configuration

The Jaeger collector accepts OTLP traces on:
- gRPC: `jaeger-collector.observability-opensearch.svc.cluster.local:4317`
- HTTP: `jaeger-collector.observability-opensearch.svc.cluster.local:4318`

### Example: Send traces using curl

```bash
# Port-forward the collector
kubectl port-forward -n observability-opensearch svc/jaeger-collector 4318:4318

# Send a test trace (example OTLP JSON)
# This requires a proper OTLP formatted trace payload
```

## Monitoring

### Prometheus Scraping

Jaeger components expose metrics that Prometheus can scrape:
- Collector metrics: Available on port 14269
- Query metrics: Available on port 16687
- Agent metrics: Available on port 14271

The `serviceMonitor` configuration in jaeger-values.yaml enables automatic discovery.

### OpenSearch Indices

Check that Jaeger indices are created in OpenSearch:

```bash
# Port-forward OpenSearch
kubectl port-forward -n observability-opensearch svc/opensearch-cluster 9200:9200

# List indices (with proper credentials)
curl -k -u admin:password https://localhost:9200/_cat/indices?v | grep jaeger
```

Expected indices:
- `jaeger-main-span-*`
- `jaeger-main-service-*`
- `jaeger-main-dependencies-*`
- `jaeger-main-sampling-*`

## Troubleshooting

### Jaeger cannot connect to OpenSearch

1. Verify OpenSearch is running:
   ```bash
   kubectl get pods -n observability-opensearch | grep opensearch
   ```

2. Check Jaeger collector logs:
   ```bash
   kubectl logs -n observability-opensearch -l app.kubernetes.io/component=collector
   ```

3. Verify credentials:
   ```bash
   kubectl get secret -n observability-opensearch admin-credentials-secret
   ```

### TLS Certificate Issues

If you encounter TLS certificate issues, you may need to adjust the certificate mount in jaeger-values.yaml. Check the actual secret name:

```bash
kubectl get secrets -n observability-opensearch | grep cert
```

Update `opensearch-cluster-transport-cert` in jaeger-values.yaml if the secret name differs.

## Cleanup

```bash
# Remove Jaeger
helm uninstall jaeger -n observability-opensearch

# Remove Prometheus
helm uninstall prometheus -n observability-opensearch
```

## Configuration Files

- `jaeger-values.yaml`: Jaeger Helm chart values with OpenSearch backend
- `prometheus-values.yaml`: Prometheus Helm chart values
- `jaeger-config-example.yaml`: Reference OTEL collector config for Jaeger
- `opensearch-cluster-crd.yaml`: OpenSearch cluster definition

## Next Steps

1. Configure applications to send traces to Jaeger collector endpoints
2. Set up Prometheus scrape configs for your applications
3. Create Grafana dashboards for visualization (optional)
4. Configure retention policies for traces in OpenSearch
