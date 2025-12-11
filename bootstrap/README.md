# TalosOS & Cilium Bootstrap für O11y-Stack

Anleitung zur Installation eines High-Availability Kubernetes-Clusters mit TalosOS und Cilium CNI.

**Dokumentation:** https://docs.siderolabs.com/talos/v1.11/getting-started/getting-started

---

## Voraussetzungen

- 3 Control-Plane Nodes (VMs oder Bare-Metal) im **Talos Maintenance Mode** (frisch von TalosOS-ISO gebootet, noch nicht konfiguriert)
- AMD64-Architektur (AMD-Microcode wird geladen)
- Disk-Zugriff auf `/dev/sda` (oder angepasst in Node-Patches)

---

## 1. Vorbereitung

### Umgebungsvariablen setzen

```bash
export CONTROL_PLANE_IP=<IP-eines-control-plane-nodes>
export CLUSTER_NAME=o11y-test-stack
```

### Disk-ID ermitteln

```bash
talosctl get disks --insecure --nodes $CONTROL_PLANE_IP
```

**Wichtig:** Disk-ID (z.B. `sda`) in `/talos/patches/nodes/cp-*.yaml` anpassen.

---

## 2. Talos-Konfiguration generieren

```bash
talosctl gen config $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443 \
  --kubernetes-version 1.33.5 \
  --output talos \
  --config-patch @patches/all/allow-scheduling.yaml \
  --config-patch @patches/all/subnets.yaml \
  --config-patch-control-plane @patches/all/amd-ucode.yaml \
  --config-patch-control-plane @patches/all/disable-cni-and-proxy.yaml \
  --config-patch-control-plane @patches/all/install-image.yaml
```

**Generiert:** `controlplane.yaml`, `talosconfig`, `worker.yaml`

### Patches erklärt

| Patch | Zweck |
|-------|-------|
| `allow-scheduling.yaml` | Erlaubt Workload-Pods auf Control-Planes (Single-Node oder Test-Cluster) |
| `subnets.yaml` | Pod-CIDR (`10.244.0.0/16`) und Service-CIDR (`10.96.0.0/16`) festlegen |
| `amd-ucode.yaml` | AMD-Microcode-Extension laden (CPU-Sicherheitsupdates) |
| `disable-cni-and-proxy.yaml` | Deaktiviert Talos-eigenen CNI/kube-proxy → Cilium übernimmt |
| `install-image.yaml` | Custom Talos-Image (nocloud) mit Factory-Image |

**Node-Patches** (`cp-01.yaml`, etc.):
- Hostname setzen (`cp-01`, `cp-02`, `cp-03`)
- Disk-Ziel pro Node (`/dev/sda`)

---

## 3. Konfiguration auf Nodes anwenden

**Node-IPs:** `192.168.109.107`, `192.168.109.108`, `192.168.109.109`

```bash
# Parallel auf alle Control-Planes
talosctl apply-config --insecure \
  --nodes 192.168.109.107 --file talos/controlplane.yaml --config-patch @patches/nodes/cp-01.yaml & \
talosctl apply-config --insecure \
  --nodes 192.168.109.108 --file talos/controlplane.yaml --config-patch @patches/nodes/cp-02.yaml & \
talosctl apply-config --insecure \
  --nodes 192.168.109.109 --file talos/controlplane.yaml --config-patch @patches/nodes/cp-03.yaml & \
wait
```

---

## 4. Cluster bootstrappen

**Einmalig** auf einem beliebigen Control-Plane Node ausführen:

```bash
talosctl --talosconfig=./talosconfig config endpoints $CONTROL_PLANE_IP
talosctl bootstrap --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig
```

### Generierte Configs löschen

```bash
rm talos/controlplane.yaml talos/worker.yaml
```

**Warum?** Alte Configs können bei erneutem Deployment zu Konflikten führen.

---

## 5. Kubeconfig abrufen

```bash
talosctl kubeconfig $CLUSTER_NAME --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig
export KUBECONFIG=./talos/$CLUSTER_NAME
kubectl get nodes
```

---

## 6. Cilium CNI installieren

### Cilium CLI installieren

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
GOOS=$(go env GOOS)
GOARCH=$(go env GOARCH)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${GOOS}-${GOARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-${GOOS}-${GOARCH}.tar.gz.sha256sum
sudo tar -C /usr/local/bin -xzvf cilium-${GOOS}-${GOARCH}.tar.gz
rm cilium-${GOOS}-${GOARCH}.tar.gz{,.sha256sum}
```

### Cilium deployen

```bash
cilium install --values cilium/values-cilium.yaml
```

**Alternativ (ohne Values-File):**

```bash
cilium install \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445
```

### Cilium-Features (aus `values-cilium.yaml`)

- **kube-proxy Replacement:** Cilium übernimmt Service-Load-Balancing (eBPF-basiert)
- **Native Routing:** Direktes Pod-zu-Pod Routing ohne Overlay
- **Hubble:** Observability-Layer (Flow-Logs, Service Map) mit UI
- **SCTP Support:** Stream Control Transmission Protocol für Multi-Homing
- **Maglev LB-Algorithmus:** Konsistentes Hashing für stabile Backend-Selektion
- **Security Capabilities:** Talos-spezifische Capabilities (z.B. `SYS_ADMIN` für eBPF)

---

## 7. Prometheus Operator CRDs (Optional)

Für Monitoring-Stack (Prometheus, Grafana):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-operator-crds prometheus-community/prometheus-operator-crds --namespace kube-system
```

**Zweck:** Installiert CRDs für `ServiceMonitor`, `PodMonitor`, `PrometheusRule` etc.

---

## Troubleshooting

**Pods starten nicht:**
```bash
cilium status --wait
kubectl get pods -A
```

**Cilium Connectivity Test:**
```bash
cilium connectivity test
```

**Talos Logs:**
```bash
talosctl logs -n $CONTROL_PLANE_IP --talosconfig=./talosconfig
```