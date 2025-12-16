# Longhorn Storage on Talos

This directory contains the configuration for Longhorn distributed block storage on our Talos Kubernetes cluster.

## Overview

Longhorn is a lightweight, reliable, and powerful distributed block storage system for Kubernetes. It provides:
- Persistent volume management
- Volume snapshots and backups
- Cross-cluster disaster recovery
- Automated non-disruptive upgrades

## Prerequisites

### Talos Configuration

The cluster nodes must have the following configurations applied:

#### 1. System Extensions

All nodes require these system extensions via Image Factory:

```yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/amd-ucode
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
```

**Image Schematic ID:** `743d53d3c9cc1942e0a3fc7167565665ea25823e6261d82bf022e9a9e50ed84d`

#### 2. Kubelet Extra Mounts

All nodes need proper mount propagation for Longhorn volumes:

```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw
```

### Verify Extensions

To verify the extensions are loaded:

```bash
talosctl get extensions --nodes <node-ip>
```

Expected output:
```
NAME               VERSION
amd-ucode          20251021
iscsi-tools        v0.2.0
util-linux-tools   2.41.1
```

## Installation

### 1. Create Namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Install Longhorn via Helm

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update

helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values values.yaml
```

### 3. Verify Installation

Check all pods are running:

```bash
kubectl get pods -n longhorn-system
```

Check Longhorn nodes:

```bash
kubectl get nodes.longhorn.io -n longhorn-system
```

## Configuration

The `values.yaml` file contains our Longhorn configuration. Key settings include:

- Default replica count
- Storage over-provisioning
- Backup targets
- Node selector and tolerations
- Resource limits

## Usage

### StorageClass

Longhorn automatically creates a `longhorn` StorageClass:

```bash
kubectl get storageclass longhorn
```

### Creating a PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

Apply and verify:

```bash
kubectl apply -f pvc.yaml
kubectl get pvc my-pvc
```

### Using in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: my-pvc
```

## Accessing Longhorn UI

Port-forward the Longhorn frontend service:

```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

Then access the UI at: http://localhost:8080

## Monitoring

Longhorn exposes Prometheus metrics on port 9500. If you have Prometheus installed, it will automatically discover and scrape Longhorn metrics.

Common metrics to monitor:
- `longhorn_volume_actual_size_bytes` - Volume usage
- `longhorn_volume_state` - Volume health status
- `longhorn_node_storage_capacity_bytes` - Node storage capacity
- `longhorn_disk_capacity_bytes` - Disk capacity per node

## Backup and Recovery

### Configure Backup Target

Longhorn supports backups to:
- NFS shares
- S3-compatible object storage
- Azure Blob Storage

Configure backup target in the UI or via settings:

```bash
kubectl edit settings.longhorn.io backup-target -n longhorn-system
```

### Create Snapshot

```bash
# Via kubectl
kubectl create -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Snapshot
metadata:
  name: my-snapshot
  namespace: longhorn-system
spec:
  volume: pvc-xxxxx
EOF
```

Or use the Longhorn UI to create snapshots interactively.

## Troubleshooting

### Check Node Status

```bash
kubectl get nodes.longhorn.io -n longhorn-system -o wide
```

### View Manager Logs

```bash
kubectl logs -n longhorn-system -l app=longhorn-manager
```

### Check Volume Status

```bash
kubectl get volumes.longhorn.io -n longhorn-system
```

### Common Issues

#### Volume Not Attaching

1. Check if iSCSI tools are loaded:
   ```bash
   talosctl read /etc/iscsi/initiatorname.iscsi --nodes <node-ip>
   ```

2. Verify mount propagation:
   ```bash
   talosctl get machineconfig -o yaml --nodes <node-ip> | grep -A 10 extraMounts
   ```

#### Node Scheduling Issues

Ensure nodes have sufficient disk space:
```bash
kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.diskStatus}{"\n"}{end}'
```

## Upgrading

To upgrade Longhorn:

```bash
helm repo update
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values values.yaml
```

Always review the [Longhorn upgrade guide](https://longhorn.io/docs/latest/deploy/upgrade/) before upgrading.

## Uninstallation

**Warning:** This will delete all volumes and data!

```bash
# Delete all PVCs first
kubectl delete pvc --all --all-namespaces

# Uninstall Longhorn
helm uninstall longhorn -n longhorn-system

# Delete namespace
kubectl delete namespace longhorn-system
```

## Resources

- [Longhorn Documentation](https://longhorn.io/docs/)
- [Longhorn GitHub](https://github.com/longhorn/longhorn)
- [Talos System Extensions](https://www.talos.dev/latest/talos-guides/configuration/system-extensions/)
- [Best Practices](https://longhorn.io/docs/latest/best-practices/)

## Cluster Information

- **Talos Version:** v1.11.5
- **Longhorn Version:** See `values.yaml`
- **Nodes:** 3 control plane nodes (cp-01, cp-02, cp-03)
- **Node IPs:** 192.168.109.107-109