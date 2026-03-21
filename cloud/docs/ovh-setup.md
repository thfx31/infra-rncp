# Mise en place des credentials OVH

## 1. Compte OVH Public Cloud

Créer un projet Public Cloud dans l'espace client OVH si ce n'est pas déjà fait.

## 2. Token API OVH

Le token API OVH est nécessaire pour Terraform (provider `ovh/ovh`) et cert-manager
(challenge DNS OVH).

### Créer l'application OVH
1. Aller sur https://www.ovh.com/auth/api/createApp
2. Remplir le nom et la description
3. Récupérer : `Application Key` et `Application Secret`

### Créer le Consumer Key
```bash
curl -XPOST -H "X-Ovh-Application: <APPLICATION_KEY>" \
  -H "Content-type: application/json" \
  -d '{"accessRules":[{"method":"GET","path":"/*"},{"method":"POST","path":"/*"},{"method":"PUT","path":"/*"},{"method":"DELETE","path":"/*"}]}' \
  https://eu.api.ovh.com/1.0/auth/credential
```
Suivre le lien `validationUrl` retourné pour valider le Consumer Key.

## 3. Credentials OpenStack

Nécessaires pour Terraform (provider `openstack`) et Cinder CSI.

1. Espace client OVH > Public Cloud > Users & Roles
2. Créer un utilisateur avec le rôle `Compute Operator` + `Object Store Operator`
3. Télécharger le fichier OpenStack RC (v3)
4. Récupérer : `OS_TENANT_ID` (= `OS_PROJECT_ID`) et le mot de passe

## 4. Clé SSH

```bash
ssh-keygen -t ed25519 -C "rncp-ovh" -f ~/.ssh/id_ed25519_ovh
```

Enregistrer la clé dans OpenStack (nom obligatoire : `rncp-ovh`, correspond à `var.ssh_key_name` dans Terraform) :

```bash
source ~/openstack-rc.sh
export OS_REGION_NAME=SBG5   # le fichier RC donne "SBG" (legacy) — utiliser SBG5
openstack keypair create --public-key ~/.ssh/id_ed25519_ovh.pub rncp-ovh
```

> **Note région :** le fichier OpenRC OVH indique `OS_REGION_NAME=SBG` mais l'endpoint API
> attend `SBG5`. Toujours surcharger avec `export OS_REGION_NAME=SBG5` après avoir sourcé le fichier RC.
> Dans Terraform, `var.ovh_region` est déjà à `SBG5` — aucune action nécessaire côté GHA.

## 5. Remote state Terraform (bucket S3 OVH)

À créer une seule fois manuellement.

```bash
# Charger les variables OpenStack RC
source ~/openstack-rc.sh

# Installer OpenStack CLI (dans un virtualenv)
pip install python-openstackclient

# Créer le bucket
openstack container create terraform-state-rncp

# Créer les credentials S3
openstack ec2 credentials create
# Récupérer : Access (= TF_BACKEND_ACCESS_KEY) et Secret (= TF_BACKEND_SECRET_KEY)
```

L'endpoint S3 OVH est : `https://s3.<REGION>.cloud.ovh.net`

## 6. Récapitulatif des valeurs à sauvegarder

| Variable | Description | Où l'utiliser |
|----------|-------------|---------------|
| `OVH_APPLICATION_KEY` | Clé app OVH | GitHub Secret |
| `OVH_APPLICATION_SECRET` | Secret app OVH | GitHub Secret |
| `OVH_CONSUMER_KEY` | Consumer Key OVH | GitHub Secret |
| `OVH_TENANT_ID` | Project ID OpenStack | GitHub Secret |
| `OS_USERNAME` | Nom d'utilisateur OpenStack (format `user-XXXXXXXX`) | GitHub Secret |
| `OS_PASSWORD` | Mot de passe user OpenStack (généré dans Users & Roles) | GitHub Secret |
| `SSH_PRIVATE_KEY` | Clé privée ED25519 | GitHub Secret |
| `LETSENCRYPT_EMAIL` | Email cert-manager | GitHub Secret |
| `TF_BACKEND_ACCESS_KEY` | S3 Access Key | GitHub Secret |
| `TF_BACKEND_SECRET_KEY` | S3 Secret Key | GitHub Secret |

→ Voir [github-actions.md](github-actions.md) pour configurer ces secrets.
