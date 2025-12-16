# kube-prometheus-stack (Meta-Monitoring)

Dieser Stack überwacht alle anderen Observability-Stacks und läuft während aller Tests kontinuierlich.

## Komponenten
- **Prometheus**: Metriken-Sammlung (7 Tage Retention)
- **Grafana**: Visualisierung
- **Node Exporter**: Hardware-Metriken (als DaemonSet auf jedem Node)
- **kube-state-metrics**: Kubernetes-spezifische Metriken

## Warum dieser Stack?

Aus Kapitel 3.3.1 der Arbeit:
> Ein zentrales methodisches Problem besteht darin, die Observability-Stacks zu observieren, 
> ohne deren Performance zu beeinträchtigen oder durch zirkuläre Abhängigkeiten zu verfälschen.

Dieser separate Stack ermöglicht die Messung aller Test-Stacks unter identischen Bedingungen.

## Installation

### 1. Helm Repository hinzufügen
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. Namespace erstellen
```bash
kubectl create namespace monitoring
```

### 3. Stack installieren
```bash
helm install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yaml \
  --wait
```

### 4. Installation verifizieren
```bash
# Alle Pods prüfen
kubectl get pods -n monitoring

# Sollte etwa zeigen:
# NAME                                                   READY   STATUS    RESTARTS   AGE
# kube-prom-kube-prometheus-operator-...                 1/1     Running   0          2m
# kube-prom-prometheus-node-exporter-...                 1/1     Running   0          2m  (auf jedem Node)
# kube-prom-kube-state-metrics-...                       1/1     Running   0          2m
# kube-prom-grafana-...                                  3/3     Running   0          2m
# prometheus-kube-prom-kube-prometheus-prometheus-0      2/2     Running   0          2m
```

## Zugriff auf Grafana
```bash
# Port-Forward einrichten
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80
```

Öffne Browser: http://localhost:3000

**Login-Daten:**
- Username: `admin`
- Password: `prom-operator`

## Wichtige vorkonfigurierte Dashboards

Nach dem Login findest du unter "Dashboards":
- **Kubernetes / Compute Resources / Namespace (Pods)** - CPU/RAM pro Namespace
- **Kubernetes / Networking / Namespace (Pods)** - Netzwerk-Traffic
- **Node Exporter / Nodes** - Hardware-Metriken der Worker Nodes

## Wichtige PromQL-Queries für die Thesis

### CPU-Verbrauch pro Namespace
```promql
sum(rate(container_cpu_usage_seconds_total{namespace!=""}[5m])) by (namespace)
```

### RAM-Verbrauch pro Namespace
```promql
sum(container_memory_working_set_bytes{namespace!=""}) by (namespace)
```

### Disk I/O (Schreibrate)
```promql
sum(rate(container_fs_writes_bytes_total{namespace!=""}[5m])) by (namespace)
```

### Netzwerk-Traffic (empfangen)
```promql
sum(rate(container_network_receive_bytes_total{namespace!=""}[5m])) by (namespace)
```

### Netzwerk-Traffic (gesendet)
```promql
sum(rate(container_network_transmit_bytes_total{namespace!=""}[5m])) by (namespace)
```

## Daten exportieren für Analyse

### Via Prometheus API
```bash
# Export als JSON (Beispiel für CPU-Daten über 1 Stunde)
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-prometheus 9090:9090

# In separatem Terminal:
curl 'http://localhost:9090/api/v1/query_range?query=sum(rate(container_cpu_usage_seconds_total{namespace="lgtm-stack"}[5m]))&start=2025-12-16T10:00:00Z&end=2025-12-16T11:00:00Z&step=30s' > cpu_data.json
```

### Via Grafana Export

1. Öffne ein Dashboard
2. Klicke auf "Share" → "Export"
3. Wähle "Export for external use" → "Save to file"


## Deinstallation
```bash
helm uninstall kube-prom --namespace monitoring
kubectl delete namespace monitoring
```

**⚠️ Achtung:** Dies löscht alle gesammelten Metriken! Exportiere wichtige Daten vorher.