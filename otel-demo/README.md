# OpenTelemetry Demo - Installation und Test-Konfiguration

Dieses Verzeichnis enthält die Helm Values-Dateien für die Installation der OpenTelemetry Astronomy Shop Demo-Applikation mit drei verschiedenen Observability-Stacks.

## Dateien-Übersicht

### Values-Dateien
- **`values-lgtm.yaml`** - Konfiguration für LGTM Stack (Loki, Grafana, Tempo, Prometheus)
- **`values-opensearch.yaml`** - Konfiguration für OpenSearch Stack
- **`values-victoriametrics.yaml`** - Konfiguration für VictoriaMetrics Stack

## Voraussetzungen

### Installierte Tools
- `kubectl`
- `helm`

### Vorinstallierte Stacks

#### Für alle Tests:
1. **kube-prometheus-stack** (Setup in [Abschnitt Monitoring](https://github.com/AlienAscension/o11y-stack-test/tree/main/monitoring)

#### Für LGTM-Test: (Setup in [Abschnitt LGTM-Stack](https://github.com/AlienAscension/o11y-stack-test/tree/main/lgtm-stack)
2. **LGTM-Stack** (im Namespace `observability-lgtm`)
   - Loki Distributor: `loki-distributor.observability-lgtm.svc.cluster.local:4317`
   - Tempo Distributor: `tempo-distributor.observability-lgtm.svc.cluster.local:4317`
   - Prometheus Server: `prometheus-server.observability-lgtm.svc.cluster.local:80`
   - Grafana: `grafana.observability-lgtm.svc.cluster.local:3000`

#### Für OpenSearch-Test:
3. **OpenSearch-Stack** (im Namespace `observability-opensearch`)
   - OpenSearch: `opensearch.observability-opensearch.svc.cluster.local:9200`
   - Fluent Bit: `fluent-bit.observability-opensearch.svc.cluster.local:24224`
   - Prometheus: `prometheus.observability-opensearch.svc.cluster.local:9090`
   - Jaeger Collector: `jaeger-collector.observability-opensearch.svc.cluster.local:4317`
   - Grafana: `grafana.observability-opensearch.svc.cluster.local:3000`

#### Für VictoriaMetrics-Test:
4. **VictoriaMetrics-Stack** (im Namespace `observability-vm`)
   - VictoriaMetrics: `victoriametrics.observability-vm.svc.cluster.local:8428`
   - VictoriaLogs: `victorialogs.observability-vm.svc.cluster.local:9428`
   - VictoriaTraces: `victoriatraces.observability-vm.svc.cluster.local:4317`
   - Grafana: `grafana.observability-vm.svc.cluster.local:3000`

## Installation

### 1. Helm Repository hinzufügen

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

### 2. Demo installieren

#### LGTM Stack
```bash
kubectl create namespace otel-demo-lgtm

helm install otel-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo-lgtm \
  --values values-lgtm.yaml \
  --wait --timeout 10m
```

#### OpenSearch Stack
```bash
kubectl create namespace otel-demo-opensearch

helm install otel-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo-opensearch \
  --values values-opensearch.yaml \
  --wait --timeout 10m
```

#### VictoriaMetrics Stack
```bash
kubectl create namespace otel-demo-victoriametrics

helm install otel-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo-victoriametrics \
  --values values-victoriametrics.yaml \
  --wait --timeout 10m
```

### 3. Installation validieren

Prüfe, ob alle Pods laufen:
```bash
# Für LGTM Stack
kubectl get pods -n otel-demo-lgtm

# Warte bis alle Pods Ready sind
kubectl wait --for=condition=Ready pods --all \
  --namespace otel-demo-lgtm \
  --timeout=600s
```

Prüfe OTEL Collector Logs auf Fehler:
```bash
kubectl logs -n otel-demo-lgtm \
  -l app.kubernetes.io/name=opentelemetry-collector \
  --tail=100
```

Prüfe ob ServiceMonitor erstellt wurde:
```bash
kubectl get servicemonitor -n otel-demo-lgtm
```

Prüfe ob kube-prom die Demo-Pods scraped:
```bash
# Port-Forward zu Prometheus
kubectl port-forward -n monitoring \
  svc/kube-prom-kube-prometheus-prometheus 9090:9090

# Öffne Browser: http://localhost:9090/targets
# Suche nach "otel-demo" Targets
```

## Output nach erfolgreicher Installation

```
All services are available via the Frontend proxy: http://localhost:8080
  by running these commands:
     kubectl --namespace otel-demo-lgtm port-forward svc/frontend-proxy 8080:8080
  The following services are available at these paths after the frontend-proxy service is exposed with port forwarding:
  Webstore             http://localhost:8080/
  Jaeger UI            http://localhost:8080/jaeger/ui/
  Grafana              http://localhost:8080/grafana/
  Load Generator UI    http://localhost:8080/loadgen/
  Feature Flags UI     http://localhost:8080/feature/
```

## Test-Durchführung

Der Test besteht aus 3 aufeinanderfolgenden Phasen mit unterschiedlichen Lastprofilen. Die Load-Generator-Konfiguration wird durch Anpassung der Umgebungsvariable `LOCUST_USERS` im Deployment gesteuert.

### Phase 1: Baseline (30 Minuten, 0 User)

Ziel: Erfasse Ressourcenverbrauch im Leerlauf ohne Last.

```bash
# Setze Load Generator auf 0 User
kubectl set env deployment/otel-demo-loadgenerator \
  -n otel-demo-lgtm \
  LOCUST_USERS=0

# Warte auf Rollout
kubectl rollout status deployment/otel-demo-loadgenerator \
  -n otel-demo-lgtm

# Warte 30 Minuten (1800 Sekunden)
echo "Phase 1 (Baseline) gestartet - 30 Minuten Wartezeit..."
sleep 1800
echo "Phase 1 abgeschlossen"
```

### Phase 2: Moderate Last (60 Minuten, 50 User)

Ziel: Simuliere normale Produktionslast.

```bash
# Setze Load Generator auf 50 User
kubectl set env deployment/otel-demo-loadgenerator \
  -n otel-demo-lgtm \
  LOCUST_USERS=50

# Warte auf Rollout
kubectl rollout status deployment/otel-demo-loadgenerator \
  -n otel-demo-lgtm

# Warte 60 Minuten (3600 Sekunden)
echo "Phase 2 (Moderate Last) gestartet - 60 Minuten Wartezeit..."
sleep 3600
echo "Phase 2 abgeschlossen"
```

### Phase 3: Spitzenlast (30 Minuten, 200 User)

Ziel: Teste Verhalten unter Extremlast.

```bash
# Setze Load Generator auf 200 User
kubectl set env deployment/otel-demo-loadgenerator \
  -n otel-demo-lgtm \
  LOCUST_USERS=200

# Warte auf Rollout
kubectl rollout status deployment/otel-demo-loadgenerator \
  -n otel-demo-lgtm

# Warte 30 Minuten (1800 Sekunden)
echo "Phase 3 (Spitzenlast) gestartet - 30 Minuten Wartezeit..."
sleep 1800
echo "Phase 3 abgeschlossen"
```

### Test-Zusammenfassung

- **Gesamtdauer**: 120 Minuten (2 Stunden)
- **Phase 1**: 0 User → 30 Min → Baseline-Messung
- **Phase 2**: 50 User → 60 Min → Normale Last
- **Phase 3**: 200 User → 30 Min → Spitzenlast

**Hinweis:** Die gleichen Befehle müssen für jeden Stack wiederholt werden, mit angepasstem Namespace:
- LGTM: `otel-demo-lgtm`
- OpenSearch: `otel-demo-opensearch`
- VictoriaMetrics: `otel-demo-victoriametrics`

### Monitoring während des Tests

#### Prometheus-Metriken abrufen
```bash
# Port-Forward zum kube-prom Prometheus
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-prometheus 9090:9090

# Öffne: http://localhost:9090
```

Wichtige Queries:
```promql
# CPU Usage der Demo-Pods
sum(rate(container_cpu_usage_seconds_total{namespace=~"otel-demo-.*"}[5m])) by (namespace, pod)

# Memory Usage
sum(container_memory_working_set_bytes{namespace=~"otel-demo-.*"}) by (namespace, pod)

# Netzwerk-Traffic
sum(rate(container_network_receive_bytes_total{namespace=~"otel-demo-.*"}[5m])) by (namespace)
sum(rate(container_network_transmit_bytes_total{namespace=~"otel-demo-.*"}[5m])) by (namespace)
```

#### Grafana Dashboard
```bash
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80
# Default credentials: admin / prom-operator
# Öffne: http://localhost:3000
```

## Stack-spezifische Hinweise

### LGTM Stack
- Traces werden direkt via OTLP gRPC an Tempo gesendet
- Metrics gehen via Prometheus Remote Write an Prometheus
- Logs werden via OTLP an Loki gesendet
- Prometheus Remote Write Receiver ist aktiviert für OTLP-Metrik-Ingestion

**Erwartete Endpunkte:**
- Tempo UI: `http://tempo-query-frontend.observability-lgtm:3100`
- Prometheus Server: `http://prometheus-server.observability-lgtm:80`
- Loki Query: `http://loki-query-frontend.observability-lgtm:3100`

### OpenSearch Stack
- Traces werden via OTLP an Jaeger Collector gesendet → OpenSearch
- Metrics via Prometheus Remote Write
- Logs werden primär von Fluent Bit DaemonSet gesammelt
- OTEL Collector sendet zusätzlich Logs via Fluent Forward

**Wichtig:**
- Fluent Bit muss als DaemonSet laufen und Container-Logs sammeln
- Jaeger speichert Traces in OpenSearch
- Kubernetes Attributes werden via k8sattributes Processor hinzugefügt

**Erwartete Endpunkte:**
- OpenSearch: `http://opensearch.observability-opensearch:9200`
- Jaeger UI: `http://jaeger-query.observability-opensearch:16686`
- Prometheus: `http://prometheus.observability-opensearch:9090`

### VictoriaMetrics Stack
- Traces via OTLP an VictoriaTraces
- Metrics via Prometheus Remote Write an VictoriaMetrics
- Logs via OTLP HTTP an VictoriaLogs
- Alle Komponenten unterstützen natives OTLP

**Besonderheiten:**
- VictoriaLogs unterstützt mehrere Ingestion-Formate (OTLP, Loki, JSON-Line)
- VictoriaMetrics ist Prometheus-kompatibel
- VictoriaTraces ist Jaeger-API-kompatibel
- Sehr ressourceneffizient

**Erwartete Endpunkte:**
- VictoriaMetrics: `http://victoriametrics.observability-vm:8428`
- VictoriaLogs: `http://victorialogs.observability-vm:9428`
- VictoriaTraces: `http://victoriatraces.observability-vm:4317`

## Cleanup

Nach Abschluss eines Tests muss die Demo deinstalliert und der Namespace gelöscht werden.

### LGTM Stack
```bash
helm uninstall otel-demo -n otel-demo-lgtm
kubectl delete namespace otel-demo-lgtm
```

### OpenSearch Stack
```bash
helm uninstall otel-demo -n otel-demo-opensearch
kubectl delete namespace otel-demo-opensearch
```

### VictoriaMetrics Stack
```bash
helm uninstall otel-demo -n otel-demo-victoriametrics
kubectl delete namespace otel-demo-victoriametrics
```

**Wichtig:** Warte mindestens 30 Minuten zwischen Tests, damit:
- Alle Ressourcen vollständig freigegeben werden
- Persistent Volumes gelöscht werden
- Der kube-prom Stack sich stabilisiert
- Metriken aus vorherigem Test nicht verfälschen

```bash
echo "Cleanup abgeschlossen. Warte 30 Minuten..."
sleep 1800
echo "Bereit für nächsten Test"
```

## Troubleshooting

### Pods starten nicht
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### OTEL Collector kann nicht exportieren
```bash
kubectl logs -n otel-demo-lgtm -l app.kubernetes.io/name=opentelemetry-collector --tail=200

# Prüfe Netzwerk-Verbindung
kubectl run -n otel-demo-lgtm curl --rm -it --image=curlimages/curl -- sh
curl -v http://tempo-distributor.observability-lgtm.svc.cluster.local:4317
```

### ServiceMonitor wird nicht erkannt
```bash
# Prüfe Labels
kubectl get servicemonitor -n otel-demo-lgtm -o yaml

# Prüfe Prometheus Targets
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-prometheus 9090:9090
# Öffne: http://localhost:9090/targets
```

### Load Generator startet nicht
```bash
kubectl logs -n otel-demo-lgtm deployment/otel-demo-loadgenerator

# Prüfe Frontend-Erreichbarkeit
kubectl run -n otel-demo-lgtm curl --rm -it --image=curlimages/curl -- sh
curl http://frontend:8080
```

## Testplan-Übersicht

Vollständiger Test-Workflow:

1. **Vorbereitung**
   - Installiere alle drei Observability-Stacks im Cluster
   - Installiere kube-prometheus-stack für Meta-Monitoring
   - Validiere dass alle Stack-Komponenten laufen

2. **Test 1: LGTM Stack**
   - Demo installieren (Namespace: `otel-demo-lgtm`)
   - Phase 1: 30 Min Baseline (0 User)
   - Phase 2: 60 Min Moderate Last (50 User)
   - Phase 3: 30 Min Spitzenlast (200 User)
   - **Gesamtdauer: 120 Minuten**
   - Cleanup + 30 Min Wartezeit

3. **Test 2: OpenSearch Stack**
   - Demo installieren (Namespace: `otel-demo-opensearch`)
   - Gleiche 3 Phasen wie Test 1
   - **Gesamtdauer: 120 Minuten**
   - Cleanup + 30 Min Wartezeit

4. **Test 3: VictoriaMetrics Stack**
   - Demo installieren (Namespace: `otel-demo-victoriametrics`)
   - Gleiche 3 Phasen wie Test 1
   - **Gesamtdauer: 120 Minuten**
   - Cleanup

5. **Auswertung**
   - Export der Metriken aus kube-prometheus
   - Vergleichende Analyse

**Gesamt-Testdauer**: ~9 Stunden
- 3× 120 Min Tests = 360 Min (6h)
- 2× 30 Min Wartezeit = 60 Min (1h)
- Installation/Validierung = ~120 Min (2h)