# CLAUDE.md — cloud2/ (Scaleway)

Déploiement de la stack K8s RNCP sur **Scaleway** — alternative à `cloud/` (OVH).
Même stack K8s (kubeadm + AlmaLinux 9), provider cloud différent.

## Différences vs cloud/ (OVH)

| Aspect | cloud/ (OVH) | cloud2/ (Scaleway) |
|--------|--------------|--------------------|
| Provider Terraform | openstack + ovh | scaleway/scaleway |
| Compute | Instances OVH (b3-8, b3-16) | DEV1-L, DEV1-XL |
| Réseau privé | vRack OpenStack (port_security requis) | VPC Private Network (pas d'anti-spoofing) |
| Stockage | Cinder CSI (OpenStack) | scaleway-csi (Block Storage Scaleway) |
| Load Balancer | OVH Octavia CCM | Scaleway CCM |
| Backend state | OVH Object Storage (GRA) | Scaleway Object Storage (fr-par) |
| OS | AlmaLinux 9 (user: almalinux) | AlmaLinux 9 (user: almalinux) |

## Rôles Ansible identiques à cloud/

Tous les rôles sont copiés tels quels :
`common`, `security`, `kubernetes-prereqs`, `containerd`, `kubeadm`,
`cluster-init`, `cluster-join`, `cilium`, `cert-manager`, `ingress-nginx`, `argocd`

## Rôles spécifiques Scaleway

- `scaleway-csi` — Block Storage CSI (remplace `cinder-csi`)
- `scaleway-ccm` — Cloud Controller Manager (remplace `ovh-lb`)

## Prérequis

### Compte Scaleway
- Créer un projet dans la console Scaleway
- Générer des API credentials : **IAM → API Keys**
- Enregistrer sa clé SSH publique : **Project Settings → SSH Keys**
- Créer un bucket Object Storage dans `fr-par` pour le state Terraform

### Secrets GitHub à configurer
```
SCW_ACCESS_KEY           ← Scaleway API key
SCW_SECRET_KEY           ← Scaleway secret key
SCW_DEFAULT_PROJECT_ID   ← ID du projet Scaleway
SCW_DEFAULT_REGION       ← fr-par
SCW_DEFAULT_ZONE         ← fr-par-2
SSH_PRIVATE_KEY          ← clé privée ED25519
LETSENCRYPT_EMAIL        ← email pour cert-manager
TF_BACKEND_ACCESS_KEY    ← Scaleway Object Storage S3 access key
TF_BACKEND_SECRET_KEY    ← Scaleway Object Storage S3 secret key
OVH_APPLICATION_KEY      ← API OVH (cert-manager DNS challenge sur yplank.fr)
OVH_APPLICATION_SECRET   ← API OVH
OVH_CONSUMER_KEY         ← API OVH
```

## Notes importantes

### Image AlmaLinux
Vérifier le nom exact de l'image avant de déployer :
```bash
scw marketplace image list | grep -i alma
```
Mettre à jour `var.image` dans `terraform/variables.tf` si nécessaire.

### Versions des charts Helm Scaleway
Les versions dans `scaleway-csi/defaults/main.yml` et `scaleway-ccm/defaults/main.yml`
doivent être vérifiées avant le premier déploiement :
```bash
helm repo add scaleway https://scaleway.github.io/helm-charts
helm repo update
helm search repo scaleway/
```

### IP privée du control plane
Les IPs privées sont assignées via DHCP par le VPC Scaleway.
L'output Terraform `control_plane_ip_private` les récupère via `private_network[0].ip`.
