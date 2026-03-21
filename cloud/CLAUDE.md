# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Vue d'ensemble

Déploiement de la stack K8s RNCP sur **OVH Public Cloud** (kubeadm, pas de K8s managé).
Miroir fonctionnel de `proxmox/` avec les simplifications cloud suivantes :

| Aspect | proxmox/ | cloud/ |
|--------|----------|--------|
| Stockage | Longhorn | Cinder CSI (OVH Block Storage natif) |
| Load Balancer | MetalLB | OVH LB managé (Terraform) |
| Sécurité réseau | Ansible role `security/` | Security groups OpenStack (Terraform) |
| Secrets | `secrets.yml` local | GitHub Secrets |
| Déploiement principal | `make` en local | GitHub Actions (`workflow_dispatch`) |
| État Terraform | local `.tfstate` | Remote backend OVH Object Storage (S3) |
| Inventaire Ansible | `inventory.yml` statique | `inventory.py` dynamique (depuis `terraform output`) |

## Prérequis

### Compte OVH
- Token API OVH : `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`
  → Créer sur https://www.ovh.com/auth/api/createApp
- Credentials OpenStack : `OVH_TENANT_ID`, `OS_PASSWORD`
  → Télécharger le fichier RC depuis l'espace client OVH > Public Cloud > Users & Roles
- Clé SSH enregistrée dans OVH Public Cloud

### Remote state Terraform (à faire une seule fois manuellement)
Créer un bucket OVH Object Storage (compatible S3) pour stocker le state Terraform :
```bash
# Via l'espace client OVH ou openstack CLI
openstack container create terraform-state-rncp
```
Récupérer les credentials S3 (`TF_BACKEND_ACCESS_KEY`, `TF_BACKEND_SECRET_KEY`) dans
l'espace client OVH > Object Storage > S3 Users.

### GitHub Secrets à configurer
```
OVH_APPLICATION_KEY       ← API OVH
OVH_APPLICATION_SECRET    ← API OVH
OVH_CONSUMER_KEY          ← API OVH
OVH_TENANT_ID             ← OpenStack project ID
OS_PASSWORD               ← OpenStack user password
SSH_PRIVATE_KEY           ← clé privée pour Ansible (ED25519)
LETSENCRYPT_EMAIL         ← email pour cert-manager
TF_BACKEND_ACCESS_KEY     ← OVH Object Storage S3
TF_BACKEND_SECRET_KEY     ← OVH Object Storage S3
```

## Déploiement

### Via GitHub Actions (recommandé)
1. Configurer les GitHub Secrets ci-dessus
2. Lancer le workflow `deploy` : Actions → Deploy K8s cluster → Run workflow
3. Vérifier avec le workflow `check` : Actions → Check cluster → Run workflow
4. Pour détruire : workflow `destroy` (protégé par environment `production`)

### En local (dev/debug)
```bash
cd cloud/
make setup              # venv + pip + galaxy
make tf-init            # initialiser Terraform + backend S3
make tf-plan            # vérifier les ressources à créer
make tf-apply           # provisionner les instances OVH
make inventory          # générer l'inventaire Ansible depuis terraform output
make ping               # vérifier la connectivité SSH
make bootstrap          # OS + containerd + kubeadm
make init-cluster       # kubeadm init/join
make kubeconfig         # récupérer kubeconfig → ~/.kube/config-ovh
make install-foundation # Cilium, cert-manager, NGINX, ArgoCD, Cinder CSI, OVH LB
make check              # santé du cluster
```

## Architecture du cluster

Trois instances OVH Public Cloud sur vRack :
- `ovh-cp-01` — control plane (flavor b3-8 : 4 vCPUs / 8 Go RAM)
- `ovh-worker-01` — workers GitLab + Harbor (flavor b3-16 : 8 vCPUs / 16 Go RAM)
- `ovh-worker-02` — Jenkins + SonarQube + Monitoring (flavor b3-16)

Réseau :
- vRack OVH pour la communication inter-instances (réseau privé)
- Accès externe via IPs publiques OVH
- Security groups gérés dans `terraform/network.tf`

## Composants spécifiques OVH

### Cinder CSI (stockage)
Le CSI driver OpenStack Cinder remplace Longhorn. Il provisionne dynamiquement des
PVCs sous forme de volumes Block Storage OVH attachés aux instances.
→ Voir `docs/cinder-csi.md` et `ansible/roles/cinder-csi/README.md`

### OVH Load Balancer (exposition services)
Un LB managé OVH provisionné par Terraform remplace MetalLB. Les services K8s de
type `LoadBalancer` reçoivent une IP via l'annotation OVH.
→ Voir `docs/ovh-lb.md` et `ansible/roles/ovh-lb/README.md`

## Documentation

Lire dans cet ordre lors de la mise en place :
1. `docs/README.md` — guide d'entrée et ordre de lecture
2. `docs/ovh-setup.md` — créer le compte et les credentials OVH
3. `docs/terraform.md` — remote state et variables
4. `docs/github-actions.md` — configurer les secrets et lancer le déploiement
5. `docs/ansible.md` — inventaire dynamique et playbooks
6. `docs/cinder-csi.md` — comprendre le stockage OVH
7. `docs/ovh-lb.md` — comprendre le Load Balancer OVH

## .gitignore spécifique
```
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/terraform.tfvars
ansible/*.retry
ansible/__pycache__/
*.pyc
.kube/
```
