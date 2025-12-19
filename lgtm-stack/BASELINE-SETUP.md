# Baseline Monitoring Setup - Troubleshooting Guide

## Problem: Dashboard zeigt "No Data"

Das Baseline-Dashboard benötigt Container-Metriken (`container_cpu_usage_seconds_total`, etc.), die **nicht** vom Prometheus im `observability-lgtm` Namespace gesammelt werden, sondern vom **kube-prometheus-stack** im `monitoring` Namespace.

## Architektur-Übersicht

```
┌─────────────────────────────────────────────────────────────┐
│  Namespace: monitoring                                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ kube-prometheus-stack                                  │ │
│  │ - Prometheus (scraped kubelet/cAdvisor)               │ │
│  │ - Grafana                                              │ │
│  │ - kube-state-metrics                                   │ │
│  │ - node-exporter                                        │ │
│  │                                                         │ │
│  │ → Sammelt Container-Metriken von ALLEN Namespaces     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ scraped
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Namespace: observability-lgtm                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ LGTM Stack                                             │ │
│  │ - Loki (Logs)                                          │ │
│  │ - Grafana (Visualisierung)                             │ │
│  │ - Tempo (Traces)                                       │ │
│  │ - Prometheus (Metrics Ingestion für OTEL Demo)        │ │
│  │                                                         │ │
│  │ → Dieser Prometheus hat KEINE Container-Metriken!     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Lösung 1: Dashboard im monitoring Grafana verwenden (Empfohlen)

### Schritt 1: Zugriff auf monitoring Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80
```

### Schritt 2: Login

- URL: http://localhost:3000
- Username: `admin`
- Password: `prom-operator`

### Schritt 3: Dashboard importieren

1. Klicke auf "+" → "Import dashboard"
2. Upload file: `grafana-dashboard-baseline.json`
3. Wähle Datasource: **Prometheus** (sollte automatisch ausgewählt sein)
4. Klicke "Import"

### ✅ Ergebnis

Das Dashboard sollte jetzt alle Metriken anzeigen!

---

## Lösung 2: LGTM Grafana mit monitoring Prometheus verbinden

Falls Sie das Dashboard im LGTM-Grafana (observability-lgtm Namespace) verwenden wollen:

### Schritt 1: Grafana Datasource hinzufügen

Die aktualisierte `grafana-values.yaml` enthält bereits die monitoring Prometheus Datasource.

Upgrade durchführen:

```bash
helm upgrade grafana grafana/grafana \
  --namespace observability-lgtm \
  --values grafana-values.yaml \
  --wait
```

### Schritt 2: Grafana Pod neu starten (falls nötig)

```bash
kubectl rollout restart deployment/grafana -n observability-lgtm
kubectl rollout status deployment/grafana -n observability-lgtm
```

### Schritt 3: Zugriff auf LGTM Grafana

```bash
kubectl port-forward -n observability-lgtm svc/grafana 3001:80
```

- URL: http://localhost:3001
- Username: `admin`
- Password: `admin123`

### Schritt 4: Datasource prüfen

1. Gehe zu: Configuration → Data Sources
2. Du solltest sehen:
   - ✅ **Prometheus** (observability-lgtm) - isDefault: true
   - ✅ **Prometheus-Monitoring** (monitoring) - für Container-Metriken
   - ✅ Loki
   - ✅ Tempo

3. Teste "Prometheus-Monitoring":
   - Klicke auf "Prometheus-Monitoring"
   - Klicke "Save & Test"
   - Sollte "Data source is working" zeigen

### Schritt 5: Dashboard importieren

1. Klicke auf "+" → "Import dashboard"
2. Upload file: `grafana-dashboard-baseline.json`
3. **WICHTIG:** Wähle bei "datasource" die Variable: **Prometheus-Monitoring**
4. Klicke "Import"

### ✅ Ergebnis

Das Dashboard sollte jetzt alle Metriken anzeigen!

---

## Verifikation: Metriken manuell testen

### Test 1: Container-Metriken vorhanden?

```bash
# Port-Forward zu monitoring Prometheus
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-prometheus 9090:9090

# In separatem Terminal:
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=container_cpu_usage_seconds_total{namespace="observability-lgtm"}' \
  | jq '.data.result | length'

# Sollte > 0 sein (z.B. 52)
```

### Test 2: CPU Query funktioniert?

```bash
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000' \
  | jq -r '.data.result[] | [.metric.pod, .value[1]] | @tsv'

# Sollte Liste der Pods mit CPU-Werten zeigen
```

### Test 3: Statistik-Query funktioniert?

```bash
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=avg_over_time((sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000)[1h:])' \
  | jq -r '.data.result[0:3]'

# Sollte 3 Pods mit Durchschnittswerten über 1h zeigen
```

---

## Häufige Fehler

### Dashboard zeigt "No Data" in Tabelle

**Ursache:** Zeitbereich zu kurz oder Queries verwenden `$__range` falsch

**Lösung:**
1. Setze Zeitbereich auf mindestens **1 Stunde** (oben rechts)
2. Prüfe dass `instant: true` in den Tabellen-Queries gesetzt ist

### "Failed to upgrade Grafana" Fehler

**Ursache:** PVC oder ConfigMap Konflikte

**Lösung:**
```bash
# Grafana Pod löschen (wird automatisch neu erstellt)
kubectl delete pod -n observability-lgtm -l app.kubernetes.io/name=grafana

# Warten bis Ready
kubectl wait --for=condition=Ready pod -n observability-lgtm -l app.kubernetes.io/name=grafana --timeout=120s
```

### Datasource "Prometheus-Monitoring" nicht verfügbar

**Ursache:** Helm Upgrade wurde nicht durchgeführt oder Grafana hat Config nicht geladen

**Lösung:**
```bash
# 1. Upgrade durchführen
helm upgrade grafana grafana/grafana \
  --namespace observability-lgtm \
  --values grafana-values.yaml

# 2. Grafana Pod neu starten
kubectl rollout restart deployment/grafana -n observability-lgtm

# 3. Logs prüfen
kubectl logs -n observability-lgtm -l app.kubernetes.io/name=grafana --tail=50
```

---

## Empfohlener Workflow für Baseline-Erfassung

### 1. Idle Baseline (30 Min)

```bash
# Stelle sicher dass OTEL Demo NICHT läuft
kubectl get pods -n otel-demo
# Sollte leer sein oder nicht existieren

# Warte 5 Minuten für "Settle"
sleep 300

# Öffne Dashboard und setze Zeitbereich: "Last 30 minutes"
# Exportiere Tabellen als CSV
```

### 2. Load Baseline (60 Min)

```bash
# Starte OTEL Demo
helm install otel-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo \
  --create-namespace \
  --values otel-demo/values-lgtm.yaml

# Warte 5 Minuten für "Settle"
sleep 300

# Optional: Load Generator starten
kubectl port-forward -n otel-demo svc/otel-demo-frontendproxy 8080:8080
# Öffne http://localhost:8080 und generiere Traffic

# Nach 60 Min: Öffne Dashboard, Zeitbereich: "Last 1 hour"
# Exportiere Tabellen als CSV
```

### 3. Daten exportieren

Im Dashboard:
1. Klicke auf Tabelle "Ressourcen-Statistik pro Komponente (Avg, P95, Max)"
2. Klicke auf "..." (3 Punkte oben rechts)
3. → "Inspect" → "Data" → "Download CSV"
4. Wiederhole für "Namespace Gesamt-Statistik"

CSV-Dateien können direkt in LaTeX-Tabellen verwendet werden!

---

## Zusätzliche Queries für Analysen

### P99 statt P95

```promql
quantile_over_time(0.99, 
  (sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000)[$__range:]
)
```

### Standard-Abweichung

```promql
stddev_over_time(
  (sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000)[$__range:]
)
```

### Median (P50)

```promql
quantile_over_time(0.50, 
  (sum by (pod) (container_memory_working_set_bytes{namespace="observability-lgtm", container!="", container!="POD"}) / 1024 / 1024)[$__range:]
)
```

---

## Support

Bei Problemen:
1. Prüfe Prometheus Status: `kubectl get pods -n monitoring`
2. Prüfe Grafana Logs: `kubectl logs -n observability-lgtm -l app.kubernetes.io/name=grafana`
3. Teste Queries manuell (siehe "Verifikation" oben)
4. Prüfe dass `serviceMonitorSelectorNilUsesHelmValues: false` in monitoring/values.yaml gesetzt ist
