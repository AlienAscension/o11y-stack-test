# Observability Stack Vergleich - Bachelorarbeit

Dieses Repository dient als öffentliches Code-Repository für meine Bachelorarbeit: **"Vergleich von Open-Source Observability Stacks in Kubernetes"**.

Die Repository-Struktur umfasst Helm Charts und Konfigurationsdateien zur Installation und zum Testen von drei verschiedenen Observability-Stacks sowie eine vorkonfigurierte OpenTelemetry Demo-Instanz für jeden Stack.

---

## Ordnerstruktur

```
.
├── bootstrap/              # TalosOS Cluster Bootstrap mit Cilium CNI
├── monitoring/             # kube-prometheus-stack für Meta-Monitoring
├── lgtm-stack/             # LGTM Stack (Loki, Grafana, Tempo, Prometheus)
├── opensearch-stack/       # OpenSearch Stack mit Jaeger und Prometheus
├── victoriametrics-stack/  # VictoriaMetrics Stack (VM, VictoriaLogs, VictoriaTraces)
├── otel-demo/              # OpenTelemetry Demo Anwendung (Astronomy Shop)
├── k6/                     # K6 Load Testing Skripte für Query-Benchmarks
├── storage/                # Longhorn Storage Class Konfiguration
└── results/                # Test-Ergebnisse und Benchmark-Daten
```

---

## Getestete Observability Stacks

Die folgenden drei Open-Source Observability Stacks werden verglichen:

1. **LGTM Stack** (Grafana Stack)
   - Loki (Logs)
   - Grafana (Visualisierung)
   - Tempo (Traces)
   - Prometheus (Metriken)

2. **OpenSearch Stack**
   - OpenSearch (Logs, Traces Storage)
   - Jaeger (Distributed Tracing)
   - Prometheus (Metriken)
   - Grafana (Visualisierung)

3. **VictoriaMetrics Stack**
   - VictoriaMetrics (Metriken)
   - VictoriaLogs (Logs)
   - VictoriaTraces (Traces)
   - Grafana (Visualisierung)

---

## Voraussetzungen

Folgende Tools werden für die Installation benötigt:

- **kubectl** - Kubernetes CLI
- **helm** (Version 3+) - Kubernetes Package Manager
- **talosctl** - TalosOS CLI (für Cluster Bootstrap)

Optional:
- **cilium** CLI - Für CNI Installation und Troubleshooting
- **k6** - Für Query Performance Benchmarks

---

## Installationsreihenfolge

### 1. Bootstrap Talos Cluster

Zuerst muss ein High-Availability Kubernetes Cluster mit TalosOS und Cilium CNI erstellt werden.

```bash
cd bootstrap/
```

Detaillierte Anleitung: [bootstrap/README.md](bootstrap/README.md)

**Zusammenfassung:**
- 3 Control-Plane Nodes mit TalosOS
- Cilium als CNI (ersetzt Talos-Standard CNI und kube-proxy)
- Kubernetes Version 1.33.5

---

### 2. Install kube-prometheus-stack (Meta-Monitoring)

Der kube-prometheus-stack überwacht alle Observability-Stacks während der Tests und läuft kontinuierlich im Hintergrund.

```bash
cd monitoring/

# Namespace erstellen
kubectl create namespace monitoring

# Stack installieren
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yaml \
  --wait
```

Detaillierte Anleitung: [monitoring/README.md](monitoring/README.md)

**Komponenten:**
- Prometheus (7 Tage Retention)
- Grafana (Login: admin / prom-operator)
- Node Exporter (DaemonSet)
- kube-state-metrics

**Zugriff auf Grafana:**
```bash
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80
# http://localhost:3000
```

---

### 3. Install einen der 3 Observability Stacks

Wähle einen der drei Stacks zur Installation aus:

#### Option A: LGTM Stack

```bash
cd lgtm-stack/

# Namespace erstellen
kubectl create namespace observability-lgtm

# Helm Repos hinzufügen
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Komponenten installieren
helm install loki grafana/loki --namespace observability-lgtm --values loki-values.yaml --wait
helm install tempo grafana/tempo --namespace observability-lgtm --values tempo-values.yaml --wait
helm install prometheus prometheus-community/prometheus --namespace observability-lgtm --values prometheus-values.yaml --wait
helm install grafana grafana/grafana --namespace observability-lgtm --values grafana-values.yaml --wait
```

Detaillierte Anleitung: [lgtm-stack/README.md](lgtm-stack/README.md)

#### Option B: OpenSearch Stack

```bash
cd opensearch-stack/

# Namespace erstellen
kubectl create namespace observability-opensearch

# OpenSearch Cluster und Komponenten installieren
# (siehe detaillierte Anleitung im Unterordner)
```

Detaillierte Anleitung: [opensearch-stack/README.md](opensearch-stack/README.md)

#### Option C: VictoriaMetrics Stack

```bash
cd victoriametrics-stack/

# Namespace erstellen
kubectl create namespace observability-vm

# VictoriaMetrics Komponenten installieren
# (siehe Konfigurationsdateien im Unterordner)
```

Konfigurationsdateien verfügbar im Unterordner.

---

### 4. Install die dazugehörige OTel-Demo Anwendung

Nach der Installation eines Observability-Stacks wird die OpenTelemetry Demo (Astronomy Shop) installiert.

```bash
cd otel-demo/

# Helm Repo hinzufügen
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Demo installieren (Beispiel für LGTM Stack)
kubectl create namespace otel-demo-lgtm

helm install otel-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo-lgtm \
  --values values-lgtm.yaml \
  --wait --timeout 10m
```

**Verfügbare Values-Dateien:**
- `values-lgtm.yaml` - Für LGTM Stack
- `values-opensearch.yaml` - Für OpenSearch Stack
- `values-victoriametrics.yaml` - Für VictoriaMetrics Stack

Detaillierte Anleitung: [otel-demo/README.md](otel-demo/README.md)

**Zugriff auf Demo-Anwendung:**
```bash
kubectl port-forward -n otel-demo-lgtm svc/frontend-proxy 8080:8080
# http://localhost:8080
```

---

## Test-Durchführung

Die Tests bestehen aus 3 Phasen mit unterschiedlichen Lastprofilen:

| Phase | Dauer | Benutzer | Zweck |
|-------|-------|----------|-------|
| **Baseline** | 30 Min | 0 | Ressourcenverbrauch im Leerlauf |
| **Moderate Last** | 60 Min | 50 | Normale Produktionslast |
| **Spitzenlast** | 30 Min | 200 | Extremlast-Verhalten |

**Gesamtdauer pro Stack:** 120 Minuten (2 Stunden)

Die Last wird durch Anpassung der `LOCUST_USERS` Umgebungsvariable im Load Generator gesteuert.

Beispiel:
```bash
# Phase 1: Baseline (0 User)
kubectl set env deployment/otel-demo-loadgenerator -n otel-demo-lgtm LOCUST_USERS=0

# Phase 2: Moderate Last (50 User)
kubectl set env deployment/otel-demo-loadgenerator -n otel-demo-lgtm LOCUST_USERS=50

# Phase 3: Spitzenlast (200 User)
kubectl set env deployment/otel-demo-loadgenerator -n otel-demo-lgtm LOCUST_USERS=200
```

Detaillierte Test-Anleitung: [otel-demo/README.md](otel-demo/README.md#test-durchführung)

---

## Query Performance Benchmarks (k6)

Zusätzlich zu den Ressourcen-Tests wurden Query-Performance-Benchmarks mit k6 durchgeführt.

```bash
cd k6/

# Beispiel: Query Benchmark für Loki
kubectl apply -f k6-query-job.yaml
```

Verfügbare Benchmarks:
- `k6-query-job.yaml` - Loki Query Performance
- `k6-query-opensearch-job.yaml` - OpenSearch Query Performance
- `k6-query-victoriametrics-job.yaml` - VictoriaLogs Query Performance

---

## Ergebnisse

Im Ordner `results/` befinden sich die Ergebnisse meiner Testläufe, unterteilt nach Stack und Testphase:

```
results/
├── lgtm/
│   ├── baseline/
│   ├── normal-load/
│   └── max-load/
├── opensearch/
│   ├── baseline/
│   ├── normal-load/
│   └── max-load/
└── victoriametrics/
    ├── baseline/
    ├── normal-load/
    └── max-load/
```

Die Ergebnisse enthalten CSV-Exporte aus Grafana mit folgenden Metriken:
- CPU-Verbrauch (Cores)
- RAM-Verbrauch (GiB)
- Netzwerk-Traffic (Rx/Tx in MB/s)
- Disk I/O (Read/Write in MB/s)
- k6 Performance-Test-Ergebnisse (JSON)

Zusätzlich sind Kompressions-Analyse-Ergebnisse für Log-Speicherung enthalten.

---

## Cleanup

Nach Abschluss der Tests sollten die Ressourcen aufgeräumt werden:

```bash
# Demo deinstallieren
helm uninstall otel-demo -n otel-demo-lgtm
kubectl delete namespace otel-demo-lgtm

# Observability Stack deinstallieren (Beispiel LGTM)
helm uninstall loki -n observability-lgtm
helm uninstall tempo -n observability-lgtm
helm uninstall prometheus -n observability-lgtm
helm uninstall grafana -n observability-lgtm
kubectl delete namespace observability-lgtm

# Meta-Monitoring Stack deinstallieren
helm uninstall kube-prom -n monitoring
kubectl delete namespace monitoring
```

**Wichtig:** Zwischen Tests 30 Minuten warten, damit alle Ressourcen vollständig freigegeben werden.

---

## Weitere Informationen

Detaillierte Anleitungen und Konfigurationen befinden sich in den jeweiligen Unterordner-READMEs:

- [bootstrap/README.md](bootstrap/README.md) - TalosOS Cluster Setup
- [monitoring/README.md](monitoring/README.md) - kube-prometheus-stack
- [lgtm-stack/README.md](lgtm-stack/README.md) - LGTM Stack Installation
- [opensearch-stack/README.md](opensearch-stack/README.md) - OpenSearch Stack Installation
- [otel-demo/README.md](otel-demo/README.md) - OpenTelemetry Demo Test-Durchführung
- [k6/README.md](k6/README.md) - Query Performance Benchmarks

---

## Lizenz

Alle verwendeten Komponenten sind Open Source. Die spezifischen Lizenzen der einzelnen Projekte sind zu beachten:

- **TalosOS**: Mozilla Public License 2.0
- **Cilium**: Apache License 2.0
- **Grafana Stack (Loki, Tempo, Grafana)**: AGPLv3
- **Prometheus**: Apache License 2.0
- **OpenSearch**: Apache License 2.0
- **Jaeger**: Apache License 2.0
- **VictoriaMetrics**: Apache License 2.0
- **OpenTelemetry Demo**: Apache License 2.0
