# Mise en place des credentials Scaleway

## 1. Compte Scaleway

Créer un compte sur https://console.scaleway.com et un **projet** dédié au déploiement RNCP.

## 2. Clé SSH

Enregistrer sa clé publique dans Scaleway — elle sera automatiquement injectée
dans toutes les instances du projet (pas besoin de la référencer dans Terraform).

```bash
# Générer une clé si nécessaire
ssh-keygen -t ed25519 -C "rncp-scaleway" -f ~/.ssh/id_ed25519

# Copier la clé publique
cat ~/.ssh/id_ed25519.pub
```

**Console Scaleway → Project Settings → SSH Keys → Add SSH Key**

> Contrairement à OVH, pas besoin de créer une keypair via CLI ni de référencer
> son nom dans Terraform. Scaleway injecte toutes les clés du projet automatiquement.

## 3. API Keys (IAM)

Nécessaires pour Terraform et les rôles Ansible Scaleway (CCM, CSI).

**Console Scaleway → IAM → API Keys → Generate API Key**

- Sélectionner le projet RNCP
- Conserver `Access Key` et `Secret Key`

## 4. Remote state Terraform (Object Storage Scaleway)

À créer une seule fois manuellement avant le premier `terraform init`.

**Option A — Console :**
Console Scaleway → Object Storage → Create Bucket
- Nom : `terraform-state-rncp`
- Région : `fr-par`
- Visibilité : **Private**

**Option B — CLI :**
```bash
# Installer le CLI Scaleway
curl -s https://raw.githubusercontent.com/scaleway/scaleway-cli/master/scripts/get.sh | sh

# Configurer
scw init

# Créer le bucket
scw object bucket create name=terraform-state-rncp region=fr-par
```

Récupérer les credentials S3 pour le bucket :
**Console → Object Storage → Credentials S3 → Generate credentials**
- `Access Key` → `TF_BACKEND_ACCESS_KEY`
- `Secret Key` → `TF_BACKEND_SECRET_KEY`

> Note : les credentials S3 Object Storage sont distincts des API Keys IAM.

## 5. Vérifier l'image AlmaLinux disponible

```bash
scw marketplace image list | grep -i alma
```

Mettre à jour `var.image` dans `terraform/variables.tf` si le nom diffère de `almalinux_9`.

## 6. Récapitulatif des valeurs à sauvegarder

| Variable GitHub Secret | Description | Obtenu depuis |
|------------------------|-------------|---------------|
| `SCW_ACCESS_KEY` | API Key Scaleway | IAM → API Keys |
| `SCW_SECRET_KEY` | API Secret Scaleway | IAM → API Keys |
| `SCW_DEFAULT_PROJECT_ID` | ID du projet Scaleway | Project Settings |
| `SSH_PRIVATE_KEY` | Clé privée ED25519 | `~/.ssh/id_ed25519` |
| `LETSENCRYPT_EMAIL` | Email pour cert-manager | — |
| `TF_BACKEND_ACCESS_KEY` | S3 Access Key Object Storage | Object Storage → Credentials |
| `TF_BACKEND_SECRET_KEY` | S3 Secret Key Object Storage | Object Storage → Credentials |
| `OVH_APPLICATION_KEY` | API OVH (DNS challenge yplank.fr) | [ovh-setup.md OVH](../../cloud/docs/ovh-setup.md) |
| `OVH_APPLICATION_SECRET` | API OVH | idem |
| `OVH_CONSUMER_KEY` | API OVH | idem |

> Les credentials OVH (`OVH_*`) sont toujours nécessaires uniquement pour le
> challenge DNS cert-manager (le domaine `yplank.fr` reste géré par OVH DNS).

→ Voir [github-actions.md](github-actions.md) pour configurer ces secrets.
