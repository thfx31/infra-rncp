# GitHub Actions — Scaleway

## Secrets à configurer

**Settings > Secrets and variables > Actions > New repository secret**

| Secret | Description | Obtenu depuis |
|--------|-------------|---------------|
| `SCW_ACCESS_KEY` | API Key Scaleway | [scaleway-setup.md](scaleway-setup.md) §3 |
| `SCW_SECRET_KEY` | API Secret Scaleway | [scaleway-setup.md](scaleway-setup.md) §3 |
| `SCW_DEFAULT_PROJECT_ID` | ID du projet Scaleway | Console → Project Settings |
| `SSH_PRIVATE_KEY` | Clé privée ED25519 | [scaleway-setup.md](scaleway-setup.md) §2 |
| `LETSENCRYPT_EMAIL` | Email cert-manager | — |
| `TF_BACKEND_ACCESS_KEY` | S3 Access Key Object Storage | [scaleway-setup.md](scaleway-setup.md) §4 |
| `TF_BACKEND_SECRET_KEY` | S3 Secret Key Object Storage | [scaleway-setup.md](scaleway-setup.md) §4 |
| `OVH_APPLICATION_KEY` | API OVH (DNS challenge yplank.fr) | cloud/docs/ovh-setup.md |
| `OVH_APPLICATION_SECRET` | API OVH | idem |
| `OVH_CONSUMER_KEY` | API OVH | idem |

> Les secrets `OVH_*` sont partagés avec le workflow `cloud/` — s'ils sont déjà
> configurés dans le dépôt, ils s'appliquent aux deux workflows.

## Workflow disponible

### `deploy-cloud` — Déployer le cluster Scaleway

**Actions > Deploy K8s cluster (Scaleway) > Run workflow**

Ce que fait le workflow :
1. `terraform init` + `terraform apply` → crée instances, IPs flexibles, VPC
2. Génère l'inventaire Ansible depuis `terraform output`
3. Attente SSH + cloud-init sur les 3 nodes
4. `bootstrap-k8s.yml` → OS + containerd + kubeadm
5. `init-cluster.yml` → kubeadm init/join
6. `install-foundation.yml` → Cilium, Scaleway CCM, Scaleway CSI, cert-manager, ingress-nginx, ArgoCD

## Récupérer le kubeconfig en local

Après déploiement :
```bash
ssh -i ~/.ssh/id_ed25519 almalinux@<CP_IP> "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config-scw
export KUBECONFIG=~/.kube/config-scw
kubectl get nodes
```

## Lancer via la CLI gh

```bash
gh workflow run deploy-cloud.yml
gh run list --workflow=deploy-cloud.yml
gh run watch
```
