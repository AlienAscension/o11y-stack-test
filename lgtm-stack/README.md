# LGTM Stack Installation

Installation von Loki, Grafana, Tempo und Prometheus für den OTEL Demo Test.

## Voraussetzungen

- Kubernetes Cluster
- `kubectl` 
- `helm`

## 1. Helm Repository hinzufügen

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

## 2. Namespace erstellen

```bash
kubectl create namespace observability-lgtm
```

## 3. Loki installieren

Loki im Single Binary Mode mit lokalem Filesystem Storage.

**Erstelle `loki-values.yaml`** (siehe separate Datei) und installiere:

```bash
helm install loki grafana/loki \
  --namespace observability-lgtm \
  --values loki-values.yaml \
  --wait \
  --timeout 10m
```

**Validierung:**
```bash
kubectl get pods -n observability-lgtm -l app.kubernetes.io/name=loki
kubectl logs -n observability-lgtm -l app.kubernetes.io/name=loki --tail=50
```

Erwartetes Ergebnis: Pod `loki-0` im Status `Running`, keine Fehler in Logs.

Prüfe ob Loki bereit ist:
```bash
kubectl exec -n observability-lgtm loki-0 -- wget -q -O- http://localhost:3100/ready
```

Sollte `ready` zurückgeben.

## 4. Tempo installieren

Tempo im Monolithic Mode mit lokalem Filesystem Storage.

**Erstelle `tempo-values.yaml`** (siehe separate Datei) und installiere:

```bash
helm install tempo grafana/tempo \
  --namespace observability-lgtm \
  --values tempo-values.yaml \
  --wait \
  --timeout 10m
```

**Validierung:**
```bash
kubectl get pods -n observability-lgtm -l app.kubernetes.io/name=tempo
kubectl logs -n observability-lgtm -l app.kubernetes.io/name=tempo --tail=50
```

Prüfe, ob OTLP Receiver auf Port 4317 lauscht:
```bash
kubectl logs -n observability-lgtm -l app.kubernetes.io/name=tempo | grep -i "otlp\|receiver"
```

Sollte Logs wie `level=info msg="OTLP receiver started"` zeigen.

## 5. Prometheus installieren

Prometheus im Monolithic Mode mit lokalem Filesystem Storage.

**Erstelle `prometheus-values.yaml`** (siehe separate Datei) und installiere:

```bash
helm install prometheus prometheus-community/prometheus \
  --namespace observability-lgtm \
  --values prometheus-values.yaml \
  --wait \
  --timeout 15m
```

**Validierung:**
```bash
kubectl get pods -n observability-lgtm -l app.kubernetes.io/name=prometheus

# Warte bis alle Pods Ready sind
kubectl wait --for=condition=Ready pods \
  -l app.kubernetes.io/name=prometheus \
  -n observability-lgtm \
  --timeout=600s
```

## 6. Grafana installieren

Grafana mit vorkonfigurierten Datasources für Loki, Tempo und Prometheus.

**Erstelle `grafana-values.yaml`** (siehe separate Datei) und installiere:

```bash
helm install grafana grafana/grafana \
  --namespace observability-lgtm \
  --values grafana-values.yaml \
  --wait \
  --timeout 10m
```

**Admin Credentials:**
- Username: `admin`
- Password: `admin123`

**Zugriff auf Grafana:**
```bash
kubectl port-forward -n observability-lgtm svc/grafana 3000:80
```

Öffne Browser: http://localhost:3000

**Validierung:**
```bash
kubectl get pods -n observability-lgtm -l app.kubernetes.io/name=grafana
```

**Datasources prüfen:**
Nach Login in Grafana:
1. Gehe zu: Configuration → Data Sources
2. Du solltest sehen:
   - ✅ Loki
   - ✅ Tempo  
   - ✅ Prometheus (als Default)

Teste jede Datasource mit "Save & Test".

## 7. Stack-Übersicht

Nach erfolgreicher Installation sollten folgende Pods laufen:

```bash
kubectl get pods -n observability-lgtm
```

Erwartete Pods:
- `loki-0` - Loki StatefulSet
- `tempo-0` - Tempo StatefulSet  
- `prometheus-server-<hash>` - Prometheus Deployment
- `grafana-<hash>` - Grafana Deployment
- `loki-gateway-<hash>` - Loki Gateway (Nginx)

Alle Pods sollten im Status `Running` sein.

## 8. Service Endpoints für OTEL Demo

Die OTEL Demo benötigt folgende Endpoints (bereits in `values-lgtm.yaml` konfiguriert):

- **Loki (Logs):** `http://loki-gateway.observability-lgtm.svc.cluster.local:80/loki/api/v1/push`
- **Tempo (Traces):** `http://tempo.observability-lgtm.svc.cluster.local:4317` (OTLP gRPC)
- **Prometheus (Metrics):** `http://prometheus-server.observability-lgtm.svc.cluster.local/api/v1/write`

**Validierung der Services:**
```bash
kubectl get svc -n observability-lgtm
```

Prüfe ob folgende Services existieren:
- `loki-gateway` (Port 80)
- `tempo` (Port 4317, 4318)
- `prometheus-server` (Port 80)
- `grafana` (Port 80)

## 9. Test der Endpoints

Teste ob die Endpoints erreichbar sind:

```bash
# Loki Ready Check
kubectl run -n observability-lgtm curl-test --rm -it --image=curlimages/curl -- \
  curl -s http://loki-gateway/ready

# Tempo Ready Check
kubectl run -n observability-lgtm curl-test --rm -it --image=curlimages/curl -- \
  curl -s http://tempo:3100/ready

# Prometheus Ready Check
kubectl run -n observability-lgtm curl-test --rm -it --image=curlimages/curl -- \
  curl -s http://prometheus-server/
```

Alle sollten `ready` oder `OK` zurückgeben.

## Troubleshooting

### Pods starten nicht

```bash
# Beschreibe Pod für Details
kubectl describe pod <pod-name> -n observability-lgtm

# Prüfe Events
kubectl get events -n observability-lgtm --sort-by='.lastTimestamp'
```

Häufige Probleme:
- **ImagePullBackOff:** Fehlende Internet-Verbindung oder Registry-Problem
- **CrashLoopBackOff:** Prüfe Logs mit `kubectl logs`
- **Pending:** Nicht genug Ressourcen im Cluster

### Service Endpoints nicht erreichbar

Prüfe DNS-Auflösung:
```bash
kubectl run -n observability-lgtm dnsutils --rm -it --image=tutum/dnsutils -- \
  nslookup loki-gateway.observability-lgtm.svc.cluster.local
```

### Grafana Datasources funktionieren nicht

Prüfe ob die Service-Namen korrekt sind:
```bash
kubectl get svc -n observability-lgtm -o wide
```

Falls Service-Namen abweichen, passe die Datasource-URLs in Grafana an.

## Deinstallation

```bash
helm uninstall loki -n observability-lgtm
helm uninstall tempo -n observability-lgtm
helm uninstall prometheus -n observability-lgtm
helm uninstall grafana -n observability-lgtm

kubectl delete namespace observability-lgtm
```

## Nächste Schritte

Nach erfolgreicher LGTM Stack Installation:
1. Validiere dass alle Endpoints erreichbar sind
2. Konfiguriere Grafana Datasources
3. Installiere die OTEL Demo mit `values-lgtm.yaml`
4. Starte den Load Test