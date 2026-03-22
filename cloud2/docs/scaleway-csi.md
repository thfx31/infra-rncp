# Scaleway Block Storage CSI

## Rôle

Le driver CSI Scaleway (`scaleway-csi`) provisionne dynamiquement des volumes
**Block Storage Scaleway** attachés aux instances en tant que PersistentVolumes K8s.

Il remplace Longhorn (`proxmox/`) et Cinder CSI (`cloud/`).

## Architecture

```
PVC créé par un pod
  → StorageClass "scaleway-bssd" (défaut)
    → scaleway-csi-controller (Deployment)
      → API Scaleway → création Block Volume
        → scaleway-csi-node (DaemonSet) → montage sur le node
```

## Credentials

Le CSI utilise un Secret K8s `scaleway-secret` (namespace `kube-system`) créé
par le rôle Ansible `scaleway-csi`. Ce secret contient :

| Clé | Source |
|-----|--------|
| `SCW_ACCESS_KEY` | Secret GitHub `SCW_ACCESS_KEY` |
| `SCW_SECRET_KEY` | Secret GitHub `SCW_SECRET_KEY` |
| `SCW_DEFAULT_PROJECT_ID` | Secret GitHub `SCW_DEFAULT_PROJECT_ID` |
| `SCW_DEFAULT_REGION` | `fr-par` |
| `SCW_DEFAULT_ZONE` | `fr-par-2` |

## Vérification post-déploiement

```bash
# Pods CSI
kubectl get pods -n kube-system | grep scaleway-csi

# StorageClass par défaut
kubectl get storageclass

# Tester un PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
EOF
kubectl get pvc test-pvc
```

## Différence vs Cinder CSI (OVH)

| Aspect | Cinder CSI (OVH) | Scaleway CSI |
|--------|-----------------|--------------|
| Credentials | user/password OpenStack | API Key Scaleway |
| Type de volume | OVH Block Storage (classic) | Scaleway b_ssd |
| Secret K8s | `cloud-config` (ini format) | `scaleway-secret` (clés/valeurs) |
