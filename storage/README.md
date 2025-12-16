# OpenEBS Local PV Storage

Minimale OpenEBS-Installation nur mit Local PV Hostpath Provisioner für persistente Volumes.

## Warum OpenEBS Local PV?

- **Minimal**: Nur 1 Pod, kein Overhead
- **Schnell**: Direkter Zugriff auf lokale Festplatte
- **Ausreichend**: Perfekt für Test-Setups ohne HA-Anforderungen
- **Keine Replikation**: Daten bleiben auf dem Node (ausreichend für Observability-Tests)

## Installation

### 1. Namespace erstellen

Der Namespace benötigt eine `privileged` PodSecurity Policy, da OpenEBS auf Host-Pfade zugreifen muss.
Der Namepsace ist in der namespace.yaml vordefiniert und so angewandt werden:

```bash
kubectl apply -f ./namespace.yaml
```

### 2. Helm Repository hinzufügen
```bash
helm repo add openebs https://openebs.github.io/openebs
helm repo update
```

### 3. OpenEBS installieren
```bash
helm install openebs openebs/openebs \
  --namespace openebs \
  --values values.yaml \
  --wait
```

### 4. Installation verifizieren
```bash
# Pod prüfen (sollte nur 1 Pod sein)
kubectl get pods -n openebs

# Sollte zeigen:
# NAME                                         READY   STATUS    RESTARTS   AGE
# openebs-localpv-provisioner-xxxxxxxxx-xxxxx  1/1     Running   0          30s

# StorageClass prüfen
kubectl get storageclass

# Sollte zeigen:
# NAME               PROVISIONER        RECLAIMPOLICY   VOLUMEBINDINGMODE
# openebs-hostpath   openebs.io/local   Delete          WaitForFirstConsumer
```

### 5. Als Default StorageClass setzen (optional)
```bash
kubectl patch storageclass openebs-hostpath \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Verifizieren:
```bash
kubectl get storageclass

# Sollte jetzt zeigen:
# NAME                         PROVISIONER        RECLAIMPOLICY   VOLUMEBINDINGMODE
# openebs-hostpath (default)   openebs.io/local   Delete          WaitForFirstConsumer
```

## Test PVC erstellen
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  storageClassName: openebs-hostpath
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

PVC Status prüfen:
```bash
kubectl get pvc test-pvc -n default

# Status "Pending" ist NORMAL!
# Grund: volumeBindingMode ist "WaitForFirstConsumer"
# PVC wird erst gebunden, wenn ein Pod sie nutzt
```

Test-Pod erstellen, der die PVC nutzt:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: test-container
    image: nginx:alpine
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
EOF
```

Jetzt sollte die PVC gebunden sein:
```bash
kubectl get pvc test-pvc -n default
# STATUS sollte jetzt "Bound" sein

kubectl get pv
# Sollte ein automatisch erstelltes PV zeigen
```

Aufräumen:
```bash
kubectl delete pod test-pod -n default
kubectl delete pvc test-pvc -n default
```

## Wichtige Hinweise

### VolumeBindingMode: WaitForFirstConsumer

Die StorageClass nutzt `WaitForFirstConsumer`, was bedeutet:
- PVC bleibt im Status `Pending` bis ein Pod sie nutzt
- Das Volume wird erst erstellt, wenn klar ist, auf welchem Node der Pod läuft
- **Vorteil**: Volume wird auf dem richtigen Node erstellt (wichtig bei multi-node Clustern)

### Storage-Pfad auf Nodes

Daten werden standardmäßig gespeichert unter:
```
/var/openebs/local/<pv-name>
```

## Deinstallation

⚠️ **Achtung**: Löscht alle persistenten Volumes und Daten!
```bash
# 1. Alle PVCs löschen, die openebs-hostpath nutzen
kubectl get pvc --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.storageClassName=="openebs-hostpath") | 
  "\(.metadata.namespace) \(.metadata.name)"' | \
  while read ns name; do
    kubectl delete pvc $name -n $ns
  done

# 2. OpenEBS deinstallieren
helm uninstall openebs --namespace openebs

# 3. Namespace löschen
kubectl delete namespace openebs

# 4. CRDs löschen (optional, wenn vollständig aufräumen)
kubectl get crd | grep openebs | awk '{print $1}' | xargs kubectl delete crd
```

## Weitere Informationen

- **Offizielle Dokumentation**: https://openebs.io/docs
- **GitHub**: https://github.com/openebs/openebs
- **Community**: Kubernetes Slack #openebs