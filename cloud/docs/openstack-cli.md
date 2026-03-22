# Commandes OpenStack CLI utiles

Référence des commandes OpenStack utilisées pour gérer le projet sur OVH Public Cloud.

## Prérequis

```bash
# Charger les credentials OpenStack
source ~/openstack-rc.sh

# Forcer la région (le fichier RC peut donner un nom incorrect)
export OS_REGION_NAME=GRA9   # compute
# export OS_REGION_NAME=GRA  # object storage
```

## Authentification

```bash
# Vérifier que les credentials fonctionnent
openstack token issue

# Afficher les quotas du projet
openstack quota show
```

## Instances (compute)

```bash
# Lister les instances
openstack server list

# Supprimer une ou plusieurs instances
openstack server delete <id_ou_nom>

# Lister les flavors disponibles
openstack flavor list

# Lister les images disponibles
openstack image list | grep -i alma
```

## Clés SSH (keypairs)

```bash
# Lister les clés enregistrées
openstack keypair list

# Enregistrer une clé publique existante
openstack keypair create --public-key ~/.ssh/id_ed25519.pub rncp-ovh

# Supprimer une clé
openstack keypair delete rncp-ovh
```

## Réseau

```bash
# Lister les réseaux
openstack network list

# Lister les subnets
openstack subnet list

# Lister les routers
openstack router list

# Détacher un subnet d'un router (avant suppression)
openstack router remove subnet <router_id> <subnet_id>

# Supprimer un router
openstack router delete <id_ou_nom>

# Supprimer un réseau
openstack network delete <id_ou_nom>
```

## IPs flottantes

```bash
# Lister les IPs flottantes
openstack floating ip list

# Supprimer une IP flottante
openstack floating ip delete <id>
```

## Security groups

```bash
# Lister les security groups
openstack security group list

# Afficher le quota security groups
openstack quota show | grep -E "secgroups|secgroup-rules"
```

## Object Storage (S3 / Swift)

```bash
# Région object storage (différente du compute)
export OS_REGION_NAME=GRA

# Lister les buckets/containers
openstack container list

# Créer un bucket
openstack container create terraform-state-rncp

# Créer des credentials S3 (pour le backend Terraform)
openstack ec2 credentials list
openstack ec2 credentials create
```

## Nettoyage complet (ordre important)

```bash
export OS_REGION_NAME=GRA9

# 1. Instances
openstack server list
openstack server delete <ids...>

# 2. IPs flottantes
openstack floating ip list
openstack floating ip delete <ids...>

# 3. Router (détacher le subnet d'abord)
openstack router remove subnet <router_id> <subnet_id>
openstack router delete <id>

# 4. Réseau privé
openstack network delete <id>
```

## Notes OVH spécifiques

- **Région compute** : `GRA9` (Gravelines) — 34 vCPUs / 44 Go RAM disponibles
- **Région object storage** : `GRA` (pour accéder aux buckets de la zone Gravelines)
- **Nom d'utilisateur OpenStack** : format `user-XXXXXXXX`, différent du login OVH
- **Mot de passe OpenStack** : généré séparément dans *Public Cloud → Users & Roles*
- **Roles nécessaires** : `Compute Operator` + `Network Operator` + `Object Store Operator`
- **Quota security groups** : `0` sur les nouveaux projets → gérer la sécurité réseau via `firewalld` (Ansible)
