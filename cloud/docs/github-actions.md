# GitHub Actions — Configuration et utilisation

## Concept

Les GitHub Actions remplacent le `make` lancé à la main. Le déploiement du
cluster est déclenché manuellement depuis l'interface GitHub (ou via la CLI `gh`).

Les credentials (OVH, SSH, etc.) sont stockés comme **GitHub Secrets** : ils ne
transitent jamais dans le code et sont injectés comme variables d'environnement
lors de l'exécution des workflows.

## Configurer les secrets

Dans le dépôt GitHub : **Settings > Secrets and variables > Actions > New repository secret**

| Secret | Valeur | Obtenu depuis |
|--------|--------|---------------|
| `OVH_APPLICATION_KEY` | Clé app OVH | [ovh-setup.md](ovh-setup.md) §2 |
| `OVH_APPLICATION_SECRET` | Secret app OVH | [ovh-setup.md](ovh-setup.md) §2 |
| `OVH_CONSUMER_KEY` | Consumer Key | [ovh-setup.md](ovh-setup.md) §2 |
| `OVH_TENANT_ID` | Project ID OpenStack | [ovh-setup.md](ovh-setup.md) §3 |
| `OS_USERNAME` | Nom d'utilisateur OpenStack (`user-XXXXXXXX`) | [ovh-setup.md](ovh-setup.md) §3 |
| `OS_PASSWORD` | Mot de passe OpenStack | [ovh-setup.md](ovh-setup.md) §3 |
| `SSH_PRIVATE_KEY` | Clé privée ED25519 (contenu complet) | [ovh-setup.md](ovh-setup.md) §4 |
| `LETSENCRYPT_EMAIL` | Ton adresse email | - |
| `TF_BACKEND_ACCESS_KEY` | S3 Access Key | [ovh-setup.md](ovh-setup.md) §5 |
| `TF_BACKEND_SECRET_KEY` | S3 Secret Key | [ovh-setup.md](ovh-setup.md) §5 |

## Configurer l'environment "production" (protection destroy)

Le workflow `destroy` est protégé par un environment GitHub qui nécessite une
approbation manuelle avant l'exécution.

1. **Settings > Environments > New environment**
2. Nommer l'environment `production`
3. Cocher **Required reviewers** et s'ajouter comme reviewer

## Workflows disponibles

### `deploy` — Déployer le cluster

**Actions > Deploy K8s cluster > Run workflow**

Ce que fait le workflow :
1. Checkout du code
2. Setup Terraform + `terraform init` (backend S3 OVH)
3. `terraform apply` → crée les instances OVH, le réseau, le LB
4. Génère l'inventaire Ansible depuis `terraform output`
5. Installe les dépendances Ansible
6. `ansible-playbook bootstrap-k8s.yml` → OS + containerd + kubeadm
7. `ansible-playbook init-cluster.yml` → kubeadm init/join
8. `ansible-playbook install-foundation.yml` → Cilium, ArgoCD, Cinder CSI, OVH LB
9. Initialise GitLab (création projet firmware-poc)
10. Affiche les mots de passe initiaux des services

### `destroy` — Détruire le cluster

**Actions > Destroy K8s cluster > Run workflow**

⚠️ Protégé par l'environment `production` — nécessite approbation.

Ce que fait le workflow :
1. Terraform init
2. `terraform destroy` → supprime toutes les ressources OVH

### `check` — Vérifier l'état du cluster

**Actions > Check cluster > Run workflow**

Ce que fait le workflow :
1. Récupère le kubeconfig depuis le control plane (via SSH)
2. Affiche : nodes, ArgoCD apps, certificats TLS, pods non Running
3. Affiche les mots de passe des services

## Récupérer le kubeconfig en local

Après un déploiement réussi, récupérer le kubeconfig pour administrer le cluster depuis ta machine :

```bash
# Remplacer <CP_IP> par l'IP publique du control plane (visible dans les logs GHA)
ssh -i ~/.ssh/id_ed25519 almalinux@<CP_IP> "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config-ovh
export KUBECONFIG=~/.kube/config-ovh
kubectl get nodes
```

> Note : `scp` ne fonctionne pas directement car le fichier appartient à root.
> Le `sudo cat` via SSH est la méthode correcte.

Pour ne pas avoir à re-exporter à chaque session, ajouter dans `~/.bashrc` ou `~/.zshrc` :
```bash
export KUBECONFIG=~/.kube/config-ovh
```

## Lancer via la CLI gh

```bash
gh workflow run deploy.yml
gh workflow run check.yml
gh run list --workflow=deploy.yml   # voir les runs en cours
gh run watch                        # suivre le run en temps réel
```
