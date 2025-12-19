# Baseline Metriken für observability-lgtm Namespace

Diese PromQL-Queries erfassen die Ressourcennutzung des LGTM-Stacks für die Baseline-Ermittlung.

## 1. CPU-Auslastung

### Durchschnittliche CPU-Auslastung pro Container (5min)
```promql
rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])
```

### Maximale CPU-Auslastung pro Container (5min)
```promql
max_over_time(rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])[1h:])
```

### Durchschnittliche CPU-Auslastung pro Pod
```promql
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m]))
```

### Gesamte CPU-Auslastung des Namespaces (in Millicores)
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000
```

### CPU-Auslastung nach Komponente
```promql
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000
```

## 2. RAM-Auslastung

### Aktuelle Memory Working Set pro Container (in MiB)
```promql
container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"} / 1024 / 1024
```

### Durchschnittliche Memory Working Set pro Pod (in MiB)
```promql
sum by (pod) (container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}) / 1024 / 1024
```

### Maximale Memory Working Set pro Pod über 1h (in MiB)
```promql
max_over_time((sum by (pod) (container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}))[1h:]) / 1024 / 1024
```

### Gesamte Memory-Nutzung des Namespaces (in MiB)
```promql
sum(container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}) / 1024 / 1024
```

### Memory-Nutzung nach Komponente (Top 10)
```promql
topk(10, sum by (pod) (container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}) / 1024 / 1024)
```

## 3. Disk I/O

### Durchschnittliche Disk Read Rate pro Container (in MiB/s, 5min)
```promql
rate(container_fs_reads_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m]) / 1024 / 1024
```

### Durchschnittliche Disk Write Rate pro Container (in MiB/s, 5min)
```promql
rate(container_fs_writes_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m]) / 1024 / 1024
```

### Gesamte Disk Read Rate des Namespaces (in MiB/s)
```promql
sum(rate(container_fs_reads_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) / 1024 / 1024
```

### Gesamte Disk Write Rate des Namespaces (in MiB/s)
```promql
sum(rate(container_fs_writes_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) / 1024 / 1024
```

### Disk I/O pro Pod (Read + Write kombiniert, in MiB/s)
```promql
sum by (pod) (
  rate(container_fs_reads_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m]) + 
  rate(container_fs_writes_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])
) / 1024 / 1024
```

### Maximale Disk Write Rate über 1h (in MiB/s)
```promql
max_over_time((sum(rate(container_fs_writes_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) / 1024 / 1024)[1h:])
```

## 4. Netzwerk-Throughput

### Durchschnittliche Network Receive Rate pro Container (in MiB/s, 5min)
```promql
rate(container_network_receive_bytes_total{namespace="observability-lgtm"}[5m]) / 1024 / 1024
```

### Durchschnittliche Network Transmit Rate pro Container (in MiB/s, 5min)
```promql
rate(container_network_transmit_bytes_total{namespace="observability-lgtm"}[5m]) / 1024 / 1024
```

### Gesamte Network Receive Rate des Namespaces (in MiB/s)
```promql
sum(rate(container_network_receive_bytes_total{namespace="observability-lgtm"}[5m])) / 1024 / 1024
```

### Gesamte Network Transmit Rate des Namespaces (in MiB/s)
```promql
sum(rate(container_network_transmit_bytes_total{namespace="observability-lgtm"}[5m])) / 1024 / 1024
```

### Network Throughput pro Pod (Receive + Transmit kombiniert, in MiB/s)
```promql
sum by (pod) (
  rate(container_network_receive_bytes_total{namespace="observability-lgtm"}[5m]) + 
  rate(container_network_transmit_bytes_total{namespace="observability-lgtm"}[5m])
) / 1024 / 1024
```

### Maximaler Network Throughput über 1h (in MiB/s)
```promql
max_over_time((
  sum(rate(container_network_receive_bytes_total{namespace="observability-lgtm"}[5m])) + 
  sum(rate(container_network_transmit_bytes_total{namespace="observability-lgtm"}[5m]))
)[1h:]) / 1024 / 1024
```

## 5. Zusammenfassende Queries für Baseline-Tabellen

### Ressourcen-Übersicht pro Komponente
```promql
# CPU (Millicores)
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000

# Memory (MiB)
sum by (pod) (container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}) / 1024 / 1024

# Disk I/O (MiB/s)
sum by (pod) (
  rate(container_fs_reads_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m]) + 
  rate(container_fs_writes_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])
) / 1024 / 1024

# Network (MiB/s)
sum by (pod) (
  rate(container_network_receive_bytes_total{namespace="observability-lgtm"}[5m]) + 
  rate(container_network_transmit_bytes_total{namespace="observability-lgtm"}[5m])
) / 1024 / 1024
```

## 6. Empfohlene Grafana Dashboard Panels

### Panel 1: CPU Usage Timeline
- **Query:** `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000`
- **Type:** Time series
- **Unit:** millicores
- **Legend:** `{{pod}}`

### Panel 2: Memory Usage Timeline
- **Query:** `sum by (pod) (container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}) / 1024 / 1024`
- **Type:** Time series
- **Unit:** MiB
- **Legend:** `{{pod}}`

### Panel 3: Disk I/O Timeline
- **Query Read:** `sum(rate(container_fs_reads_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) / 1024 / 1024`
- **Query Write:** `sum(rate(container_fs_writes_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) / 1024 / 1024`
- **Type:** Time series
- **Unit:** MiB/s
- **Legend:** Read/Write

### Panel 4: Network Throughput Timeline
- **Query Receive:** `sum(rate(container_network_receive_bytes_total{namespace="observability-lgtm"}[5m])) / 1024 / 1024`
- **Query Transmit:** `sum(rate(container_network_transmit_bytes_total{namespace="observability-lgtm"}[5m])) / 1024 / 1024`
- **Type:** Time series
- **Unit:** MiB/s
- **Legend:** Receive/Transmit

### Panel 5: Resource Summary Table
- **Type:** Table
- **Queries:**
  - CPU: `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000`
  - Memory: `sum by (pod) (container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}) / 1024 / 1024`
  - Disk I/O: `sum by (pod) (rate(container_fs_writes_bytes_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) / 1024 / 1024`
  - Network: `sum by (pod) (rate(container_network_transmit_bytes_total{namespace="observability-lgtm"}[5m])) / 1024 / 1024`
- **Transform:** Join by field (pod)
- **Columns:** Pod | CPU (mc) | Memory (MiB) | Disk Write (MiB/s) | Network TX (MiB/s)

## 7. Baseline-Erfassung

### Empfohlene Vorgehensweise:

1. **Idle Baseline** (keine Last)
   - Erfasse Metriken über 30 Minuten ohne Last
   - Verwende 5min Rate für stabile Werte

2. **Load Baseline** (mit OTEL Demo)
   - Starte OTEL Demo
   - Erfasse Metriken über 30-60 Minuten mit verschiedenen Lastprofilen
   - Verwende 5min Rate + max_over_time für Peak-Werte

3. **Aggregation**
   - Durchschnitt (avg_over_time)
   - P95/P99 (quantile_over_time)
   - Maximum (max_over_time)
   - Minimum (min_over_time)

### Beispiel für P95-Werte über 1h:
```promql
# CPU P95
quantile_over_time(0.95, 
  sum(rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m]))[1h:] * 1000
)

# Memory P95
quantile_over_time(0.95, 
  sum(container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"})[1h:]
) / 1024 / 1024
```

## 8. Export für LaTeX-Tabellen

Sie können die Werte in Grafana als CSV exportieren oder mit dem Prometheus API abfragen:

```bash
# Beispiel: Aktuelle CPU-Werte abrufen
kubectl port-forward -n observability-lgtm svc/prometheus-server 9090:80

# In separatem Terminal:
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000' \
  | jq -r '.data.result[] | [.metric.pod, .value[1]] | @csv'
```

## Hinweise

- Die Metriken werden von kube-state-metrics und dem Container Runtime (containerd/cri-o) bereitgestellt
- Stellen Sie sicher, dass Prometheus die cAdvisor-Metriken scraped (sollte standardmäßig aktiviert sein)
- Für genauere Heap-Memory-Analysen (insbesondere für Java-Anwendungen) könnten JMX-Exporter zusätzlich sinnvoll sein
- Die `container!="POD"` Filter entfernen die Pause-Container der Pods
- Rate-Berechnungen verwenden 5min-Fenster für stabile Werte (kann angepasst werden)
