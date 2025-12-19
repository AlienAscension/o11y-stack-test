# LGTM Stack Monitoring mit kube-prometheus-stack

Dieser Guide beschreibt, wie Sie den LGTM Stack mit dem kube-prometheus-stack im `monitoring` Namespace überwachen.

## Architektur

```
┌─────────────────────────────────────────────────────┐
│  Namespace: monitoring                               │
│                                                      │
│  ┌────────────────────────────────────────────────┐ │
│  │ kube-prometheus-stack                          │ │
│  │                                                 │ │
│  │  - Prometheus (scraped alle Container)        │ │
│  │  - Grafana (Visualisierung & Baseline Export) │ │
│  │  - kube-state-metrics                          │ │
│  │  - node-exporter (DaemonSet)                   │ │
│  └────────────────────────────────────────────────┘ │
│                      ▲                               │
└──────────────────────┼───────────────────────────────┘
                       │
                       │ scrapes
                       │
┌──────────────────────┼───────────────────────────────┐
│  Namespace: observability-lgtm                       │
│                      │                               │
│  ┌───────────────────▼──────────────────────────┐   │
│  │ LGTM Stack (wird überwacht)                  │   │
│  │                                               │   │
│  │  - Loki (Logs)                               │   │
│  │  - Tempo (Traces)                            │   │
│  │  - Prometheus (OTEL Metrics Ingestion)       │   │
│  │  - Grafana (optional, nicht für Monitoring)  │   │
│  │  - Alloy (Collector)                         │   │
│  └──────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Zugriff auf monitoring Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80
```

**Login:**
- URL: http://localhost:3000
- Username: `admin`
- Password: `prom-operator`

### 2. Baseline Dashboard importieren

1. Öffne http://localhost:3000
2. Login mit `admin` / `prom-operator`
3. Klicke auf **"+"** (linke Sidebar) → **"Import dashboard"**
4. Klicke **"Upload JSON file"**
5. Wähle: `lgtm-stack/grafana-dashboard-baseline.json`
6. Datasource sollte automatisch auf **"Prometheus"** gesetzt sein
7. Klicke **"Import"**

### ✅ Fertig!

Das Dashboard zeigt jetzt:
- CPU-Auslastung (Millicores) aller LGTM Stack Komponenten
- Memory-Auslastung (MiB) - Working Set
- Disk I/O (MiB/s) - Read + Write
- Netzwerk-Throughput (MiB/s) - Receive + Transmit
- **Statistik-Tabellen mit Avg, P95, Max** für Baseline-Export

## Baseline-Messungen durchführen

### Idle Baseline (ohne Last)

```bash
# 1. Stelle sicher, dass OTEL Demo NICHT läuft
kubectl get pods -n otel-demo
# Sollte leer sein oder "No resources found"

# 2. Warte 5 Minuten für "Settle"
echo "Warte 5 Minuten..." && sleep 300

# 3. Öffne Dashboard
#    - Zeitbereich: "Last 30 minutes"
#    - Exportiere CSV der Statistik-Tabelle

# 4. CSV Export:
#    - Klicke auf "Ressourcen-Statistik pro Komponente" Panel
#    - "..." (3 Punkte) → "Inspect" → "Data" → "Download CSV"
#    - Speichere als: baseline-idle.csv
```

### Load Baseline (mit OTEL Demo)

```bash
# 1. Starte OTEL Demo (falls noch nicht installiert)
helm install otel-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo \
  --create-namespace \
  --values otel-demo/values-lgtm.yaml

# 2. Warte 5 Minuten für "Settle"
echo "Warte 5 Minuten..." && sleep 300

# 3. (Optional) Load Generator für realistischen Traffic
kubectl port-forward -n otel-demo svc/otel-demo-frontendproxy 8080:8080 &
# Öffne http://localhost:8080 und klicke durch die Demo-App

# 4. Warte 60 Minuten für aussagekräftige Daten
echo "Lass den Test 60 Minuten laufen..."

# 5. Öffne Dashboard
#    - Zeitbereich: "Last 1 hour"
#    - Exportiere CSV der Statistik-Tabelle
#    - Speichere als: baseline-load.csv
```

## Dashboard-Features

### Timeline-Panels (Obere Panels)

- **CPU Usage Timeline:** Zeigt CPU-Verbrauch pro Pod über Zeit
- **Memory Usage Timeline:** Zeigt Memory-Verbrauch pro Pod über Zeit
- **Disk I/O Timeline:** Gesamte Read/Write Rates des Namespaces
- **Network Timeline:** Gesamte Receive/Transmit Rates des Namespaces

**Legend zeigt:** Mean, Max, Last

### Stat-Panels (Rechte Seite)

Zeigen Namespace-Gesamt-Werte mit:
- **Last:** Aktueller Wert
- **Mean:** Durchschnitt über Zeitbereich
- **Max:** Maximum über Zeitbereich

**Thresholds:**
- CPU: Grün < 500m, Gelb < 1000m, Rot > 1000m
- Memory: Grün < 1024 MiB, Gelb < 2048 MiB, Rot > 2048 MiB

### Statistik-Tabelle (Unterer Panel)

**"Ressourcen-Statistik pro Komponente (Avg, P95, Max)"**

Zeigt für jeden Pod:
- **CPU:** Durchschnitt (Ø), P95, Maximum in Millicores
- **Memory:** Durchschnitt (Ø), P95, Maximum in MiB
- **Disk I/O:** Read Ø, Write Ø, Write Max in MiB/s
- **Network:** RX Ø, TX Ø, TX Max in MiB/s

**Export:** Ideal für LaTeX-Tabellen!

### Namespace Gesamt-Tabelle

**"Namespace Gesamt-Statistik"**

Zeigt aggregierte Werte (Summe aller Pods):
- CPU Durchschnitt & Maximum
- Memory Durchschnitt & Maximum
- Disk I/O Durchschnitt & Maximum
- Network Durchschnitt & Maximum

## Wichtige Queries

Alle Queries sind in `baseline-queries.md` dokumentiert.

### Beispiel: CPU P95 über 1h manuell abfragen

```bash
# Port-Forward zu Prometheus
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-prometheus 9090:9090

# In separatem Terminal:
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=quantile_over_time(0.95, (sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="observability-lgtm", container!="", container!="POD"}[5m])) * 1000)[1h:])' \
  | jq -r '.data.result[] | [.metric.pod, .value[1]] | @tsv' \
  | sort -k2 -rn
```

## Troubleshooting

### Dashboard zeigt "No Data"

**Check 1: Prometheus läuft?**
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
# Sollte: prometheus-kube-prom-kube-prometheus-prometheus-0   2/2   Running
```

**Check 2: Container-Metriken vorhanden?**
```bash
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-prometheus 9090:9090

# Separates Terminal:
curl -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total{namespace="observability-lgtm"}' \
  | jq '.data.result | length'

# Sollte > 0 sein (z.B. 52)
```

**Check 3: LGTM Stack läuft?**
```bash
kubectl get pods -n observability-lgtm
# Alle Pods sollten Running sein
```

**Check 4: Zeitbereich richtig gesetzt?**
- Für Statistik-Tabelle: Mindestens **1 Stunde** Zeitbereich wählen
- `$__range` Variable braucht genug Daten

### Statistik-Tabelle zeigt "No Data"

**Ursache:** Queries mit `avg_over_time` und `$__range` brauchen ausreichend Zeitbereich.

**Lösung:**
1. Setze Zeitbereich auf **"Last 1 hour"** oder mehr
2. Warte 5-10 Sekunden bis Panel refreshed
3. Bei neuem LGTM Stack: Warte mindestens 15 Minuten, damit genug Daten vorhanden sind

### CSV Export enthält leere Werte

**Ursache:** Manche Pods haben keine Disk I/O oder Network Activity.

**Lösung:** Normal! Einige Komponenten haben minimalen I/O:
- `loki-canary`: Nur minimal CPU/Memory
- `prometheus-prometheus-pushgateway`: Meist idle
- Leere Werte = 0 oder sehr kleine Werte

## Daten für LaTeX verwenden

### CSV in LaTeX-Tabelle konvertieren

1. Öffne `baseline-idle.csv` in Editor
2. Format ist bereits tab-separated, perfekt für LaTeX

Beispiel CSV:
```csv
Pod,CPU Ø (m),CPU P95 (m),CPU Max (m),Mem Ø (MiB),...
loki-0,22.5,28.3,35.2,512.3,...
grafana-...,3.8,5.1,6.8,256.1,...
```

LaTeX-Tabelle:
```latex
\begin{table}[htbp]
\centering
\caption{LGTM Stack Baseline - Idle}
\begin{tabular}{lrrrr}
\toprule
Pod & CPU Ø (m) & CPU P95 (m) & CPU Max (m) & Mem Ø (MiB) \\
\midrule
loki-0 & 22.5 & 28.3 & 35.2 & 512.3 \\
grafana-... & 3.8 & 5.1 & 6.8 & 256.1 \\
\bottomrule
\end{tabular}
\end{table}
```

### Automatische Konvertierung (Optional)

```bash
# CSV zu LaTeX mit Python pandas
pip install pandas tabulate

python3 << 'EOF'
import pandas as pd
df = pd.read_csv('baseline-idle.csv')
print(df.to_latex(index=False, float_format="%.2f"))
EOF
```

## Kontinuierliches Monitoring während Tests

### Empfohlenes Setup

Terminal 1 - Port-Forward:
```bash
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80
```

Terminal 2 - OTEL Demo (wenn benötigt):
```bash
kubectl port-forward -n otel-demo svc/otel-demo-frontendproxy 8080:8080
```

Terminal 3 - Logs beobachten:
```bash
# Loki Logs
kubectl logs -n observability-lgtm -l app.kubernetes.io/name=loki -f

# Oder alle Pods
kubectl get pods -n observability-lgtm -w
```

Browser:
- http://localhost:3000 - Grafana (Baseline Monitoring)
- http://localhost:8080 - OTEL Demo (Traffic Generator)

## Nächste Schritte

Nach Baseline-Erfassung:

1. ✅ Idle Baseline exportiert → `baseline-idle.csv`
2. ✅ Load Baseline exportiert → `baseline-load.csv`
3. 📊 Vergleiche beide CSVs
4. 📈 Erstelle LaTeX-Tabellen für Thesis
5. 🔬 Analysiere Unterschiede (welche Komponente unter Last am meisten?)

## Hinweise

- **Retention:** Prometheus speichert 7 Tage (siehe `monitoring/values.yaml`)
- **Scrape Interval:** 30s (gute Balance zwischen Granularität und Storage)
- **Storage:** 30 Gi PVC für Prometheus Daten
- **Backup:** Exportiere wichtige Daten vor Stack-Deinstallation!

## Deinstallation (nach Tests)

```bash
# WARNUNG: Löscht alle gesammelten Metriken!

# 1. Exportiere Dashboards und CSVs!

# 2. LGTM Stack deinstallieren
helm uninstall loki -n observability-lgtm
helm uninstall tempo -n observability-lgtm
helm uninstall prometheus -n observability-lgtm
helm uninstall grafana -n observability-lgtm
helm uninstall alloy -n observability-lgtm

kubectl delete namespace observability-lgtm

# 3. Monitoring Stack (optional, behalten für weitere Tests!)
helm uninstall kube-prom -n monitoring
kubectl delete namespace monitoring
```
