# Rôle : cinder-csi

## Qu'est-ce que Cinder CSI ?

**Cinder** est le service de Block Storage d'OpenStack (la plateforme cloud
qu'OVH utilise en dessous). Il permet de créer des volumes disque persistants
et de les attacher à des instances.

**CSI** (Container Storage Interface) est le standard Kubernetes pour les
pilotes de stockage. Le driver `cinder-csi-plugin` fait le lien entre
Kubernetes et Cinder : quand un pod demande un PVC (PersistentVolumeClaim),
Kubernetes demande au CSI de créer un volume OVH et de l'attacher à la bonne instance.

```
Pod demande PVC
      ↓
Kubernetes → cinder-csi-plugin → OVH Block Storage API
                                        ↓
                               Création volume 10 Go
                                        ↓
                          Attachement à l'instance worker
```

## Pourquoi à la place de Longhorn ?

Longhorn crée un stockage distribué en répliquant les données sur les disques
locaux des nodes. C'est utile sur bare-metal où l'hyperviseur ne gère pas la
redondance. Sur OVH, les disques des instances sont déjà redondants (RAID côté
hyperviseur), donc Longhorn apporte de la complexité sans bénéfice.

Cinder CSI est plus simple : OVH gère la redondance, Kubernetes provisionne
les volumes à la demande.

## Ce que fait ce rôle

1. Déploie le `cinder-csi-plugin` via Helm dans le namespace `kube-system`
2. Crée un `Secret` avec les credentials OpenStack (nécessaire pour que le CSI
   appelle l'API OVH)
3. Crée une `StorageClass` `ovh-block-storage` définie comme default

## Configuration

Fichier `defaults/main.yml` :
```yaml
cinder_csi_version: "2.x.x"   # version du chart Helm
ovh_region: "GRA9"            # région OVH
storage_class_type: "classic"  # type de volume OVH (classic, high-speed, high-speed-gen2)
```

## Vérification post-déploiement

```bash
kubectl get sc                         # StorageClass ovh-block-storage (default)
kubectl get pods -n kube-system | grep cinder  # pods du CSI driver
```

Pour tester avec un PVC de 1 Go :
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF
kubectl get pvc test-pvc   # doit passer en Bound
```
