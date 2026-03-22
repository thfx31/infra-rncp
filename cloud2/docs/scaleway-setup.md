# Mise en place des credentials Scaleway

## 1. Compte Scaleway

Créer un compte sur https://console.scaleway.com et un **projet** dédié au déploiement RNCP.

## 2. Clé SSH

Enregistrer sa clé publique dans Scaleway — elle sera automatiquement injectée
dans toutes les instances du projet (pas besoin de la référencer dans Terraform).

```bash
# Générer une clé si nécessaire
ssh-keygen -t ed25519 -C "rncp-scaleway" -f ~/.ssh/id_ed25519-scw

# Copier la clé publique
cat ~/.ssh/id_ed25519-csw.pub
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

**Console :**
Console Scaleway → Object Storage → Create Bucket
- Nom : `terraform-state-rncp`
- Région : `fr-par`
- Visibilité : **Private**

Les credentials S3 sont les **mêmes que les API Keys IAM** (section 3) — pas besoin
d'en générer de nouveaux. Utiliser le même Access Key / Secret Key pour
`TF_BACKEND_ACCESS_KEY` / `TF_BACKEND_SECRET_KEY`.

## 5. Récapitulatif des valeurs à sauvegarder

| Variable GitHub Secret | Description | Obtenu depuis |
|------------------------|-------------|---------------|
| `SCW_ACCESS_KEY` | API Key Scaleway | IAM → API Keys |
| `SCW_SECRET_KEY` | API Secret Scaleway | IAM → API Keys |
| `SCW_DEFAULT_PROJECT_ID` | ID du projet Scaleway | Project Settings |
| `SSH_PRIVATE_KEY` | Clé privée ED25519 | `~/.ssh/id_ed25519` |
| `LETSENCRYPT_EMAIL` | Email pour cert-manager | — |
| `TF_BACKEND_ACCESS_KEY` | S3 Access Key (= SCW_ACCESS_KEY) | IAM → API Keys |
| `TF_BACKEND_SECRET_KEY` | S3 Secret Key (= SCW_SECRET_KEY) | IAM → API Keys |
| `OVH_APPLICATION_KEY` | API OVH (DNS challenge yplank.fr) | [ovh-api.md](ovh-api.md) |
| `OVH_APPLICATION_SECRET` | API OVH | idem |
| `OVH_CONSUMER_KEY` | API OVH | idem |

> Les credentials OVH (`OVH_*`) sont nécessaires uniquement pour le
> challenge DNS cert-manager (le domaine `yplank.fr` reste géré par OVH DNS).

→ Voir [github-actions.md](github-actions.md) pour configurer ces secrets.
