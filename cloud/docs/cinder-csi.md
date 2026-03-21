# Cinder CSI — Stockage sur OVH Public Cloud

## Contexte

Dans `proxmox/`, **Longhorn** crée un stockage distribué en répliquant les données
sur les disques locaux des nodes. C'est utile sur bare-metal pour la résilience.

Sur OVH Public Cloud, les disques des instances sont déjà gérés par l'hyperviseur
(redondance matérielle, snapshots). Longhorn apporterait de la complexité sans
bénéfice réel. On utilise à la place le **Cinder CSI driver**.

## Architecture de stockage OVH

```
Kubernetes PVC
     ↓ (StorageClass: ovh-block-storage)
cinder-csi-plugin (pod dans kube-system)
     ↓ (appel API OpenStack)
OVH Block Storage (volume de 10 Go, 50 Go, etc.)
     ↓ (attachement)
Instance OVH (/dev/vdb, /dev/vdc...)
     ↓ (montage)
Pod (accès /data ou autre)
```

## Types de volumes OVH disponibles

| Type | Usage | Performance |
|------|-------|-------------|
| `classic` | Données froides, archives | Standard |
| `high-speed` | Applications web, bases de données | NVMe |
| `high-speed-gen2` | Workloads intensifs | NVMe dernière génération |

Pour ce POC, `classic` est suffisant.

## Comment Kubernetes utilise Cinder CSI

### Provisionnement automatique (Dynamic Provisioning)

Quand ArgoCD déploie GitLab et que GitLab demande un PVC de 50 Go :

1. Kubernetes voit la `StorageClass` `ovh-block-storage` (définie comme default)
2. Appelle le CSI driver
3. Le CSI appelle l'API OVH → crée un volume Block Storage de 50 Go
4. L'attache à l'instance worker où le pod est schedulé
5. Le pod démarre avec `/dev/vdb` monté

### Cycle de vie

- Le volume OVH est créé **à la demande** (pas en avance)
- Il est supprimé quand le PVC est supprimé (politique `Delete` par défaut)
- Ou conservé si la politique est `Retain` (à configurer selon les besoins)

## Déploiement

Géré par le rôle Ansible `ansible/roles/cinder-csi/`.
Voir le README du rôle pour les détails de configuration et de vérification.

## Limites à connaître

- `ReadWriteOnce` uniquement (un seul pod en écriture à la fois) — pas de `ReadWriteMany`
- Pour les besoins de partage de fichiers entre pods (ex: GitLab), utiliser
  OVH Object Storage (S3) ou NFS à la place
- Les volumes attachés ne peuvent pas migrer entre zones de disponibilité
