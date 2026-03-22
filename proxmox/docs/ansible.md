# Ansible — Bootstrap & Fondation Kubernetes

## Prérequis

- Python 3.x installé sur la machine de dev
- Accès SSH par clé vers les nodes K8s (user `admintf`, sudo sans mot de passe)
- Résolution DNS des hostnames `rncp-cp-01`, `rncp-worker-01`, `rncp-worker-02`
- `kubectl` et `helm` installés localement (pour les playbooks fondation)
- Credentials API OVH pour cert-manager (voir [Gestion des secrets](#gestion-des-secrets))

## Installer les packages sur le bastion
```bash
sudo dnf makecache --refresh
sudo dnf install -y python3 python3-pip git vim
```

## Setup de l'environnement

Depuis la racine du dépôt :

```bash
# Installation complète (virtualenv + dépendances Python + collections Ansible)
make setup

# Activer le virtualenv
source ~/.virtualenvs/ansible/bin/activate

# Ajouter un alias au bashrc
echo 'monenv="source ~/.virtualenv/ansible/bin/activate"' >> ~/.bashrc
source ~/.bashrc
```

Le setup installe :

| Fichier | Contenu |
|---------|---------|
| `ansible/requirements.txt` | Dépendances Python : `ansible`, `lint`, `kubernetes` |
| `ansible/requirements.yml` | Collections Ansible Galaxy : `ansible.posix`, `kubernetes.core` |

Pour mettre à jour les dépendances après modification des fichiers requirements :

```bash
make pip-install      # dépendances Python uniquement
make galaxy-install   # collections Ansible uniquement
```

## Inventory

L'inventory (`ansible/inventory.yml`) définit trois groupes :

| Groupe | Hosts | Usage |
|--------|-------|-------|
| `control_plane` | `rncp-cp-01` | Node control plane Kubernetes |
| `workers` | `rncp-worker-01`, `rncp-worker-02` | Nodes worker Kubernetes |
| `k8s_cluster` | tous | Groupe parent pour les playbooks de bootstrap |

La résolution des hostnames se fait par DNS. Les variables de connexion (`remote_user`, `become`, `private_key_file`) sont centralisées dans `ansible/ansible.cfg`.

## Gestion des secrets

Le playbook `install-foundation.yml` nécessite des credentials API OVH pour le challenge DNS Let's Encrypt. Ces secrets ne doivent **jamais** être commités dans le dépôt.

### Obtenir les credentials OVH

1. Aller sur [api.ovh.com/createToken](https://api.ovh.com/createToken/index.cgi?GET=/domain/zone/*&PUT=/domain/zone/*&POST=/domain/zone/*&DELETE=/domain/zone/*) et se connecter
2. Remplir :
   - **Application name** : `cert-manager-webhook-ovh`
   - **Validity** : Unlimited
   - **Rights** : `GET/PUT/POST/DELETE /domain/zone/*` (pré-rempli)
3. Noter les 3 valeurs : `Application Key`, `Application Secret`, `Consumer Key`

### Créer le fichier secrets

Créer `ansible/secrets.yml` (ce fichier est dans `.gitignore`) :

```yaml
ovh_application_key: "votre-application-key"
ovh_application_secret: "votre-application-secret"
ovh_consumer_key: "votre-consumer-key"
letsencrypt_email: "votre@email.fr"
```

Le fichier est passé au playbook via `-e @secrets.yml` (voir commandes ci-dessous).

## Playbooks

### `bootstrap-k8s.yml` — Bootstrap des nodes

Prépare les 3 nodes à recevoir Kubernetes. Cible : `k8s_cluster`.

```bash
make bootstrap
```

Exécute les rôles suivants dans l'ordre :

| Rôle | Description |
|------|-------------|
| `common` | Mise à jour des paquets, installation des outils de base (curl, wget, vim, chrony, conntrack-tools, iproute-tc...), configuration du hostname |
| `security` | Installation et activation de SELinux en mode **enforcing**, installation et configuration de firewalld avec les ports nécessaires (API Server, etcd, Kubelet, NodePort, Cilium, iSCSI) |
| `kubernetes-prereqs` | Désactivation du swap, chargement des modules noyau (`overlay`, `br_netfilter`), configuration sysctl (`ip_forward`, `bridge-nf-call-iptables`) |
| `containerd` | Ajout du repo Docker CE, installation de containerd, génération de la config par défaut, activation du plugin CRI, activation de SystemdCgroup |
| `kubeadm` | Ajout du repo Kubernetes (v1.31), installation de kubeadm, kubelet et kubectl, activation du service kubelet |

### `init-cluster.yml` — Initialisation du cluster

Initialise le control plane puis joint les workers. Exécution one-shot.

```bash
make init-cluster
```

| Rôle | Cible | Description |
|------|-------|-------------|
| `cluster-init` | `control_plane` | `kubeadm init` avec pod CIDR `10.244.0.0/16`, configuration du kubeconfig pour `admintf`, génération du token join |
| `cluster-join` | `workers` | `kubeadm join` avec le token récupéré du control plane |

Le playbook termine par un `kubectl get nodes` pour vérifier l'état du cluster.

### `install-foundation.yml` — Composants fondation

Installe les composants infrastructure sur le cluster. Nécessite le kubeconfig et les secrets OVH.

```bash
# Récupérer le kubeconfig d'abord
make kubeconfig

# Installer les composants
make install-foundation
```

Le playbook comporte deux plays :

**Play 1** — Prérequis sur les nodes (SSH + sudo) :
- Installation de `iscsi-initiator-utils` et `nfs-utils` pour Longhorn
- Activation du service `iscsid`

**Play 2** — Déploiement via l'API Kubernetes (localhost) :

| Rôle | Description |
|------|-------------|
| `cilium` | CNI Cilium v1.16.5 via Helm dans `kube-system`, avec Hubble (observabilité réseau) activé |
| `metallb` | Load Balancer bare-metal MetalLB v0.14.9 via Helm dans `metallb-system`, pool d'IP `192.168.1.140-150`, annonce L2 |
| `longhorn` | Stockage distribué Longhorn v1.7.2 via Helm dans `longhorn-system`, 2 réplicas par volume |
| `cert-manager` | Gestion de certificats TLS cert-manager v1.17.1 via Helm dans `cert-manager`, webhook OVH pour challenge DNS-01, ClusterIssuer Let's Encrypt production |
| `ingress-nginx` | Ingress Controller NGINX v4.12.1 via Helm dans `ingress-nginx`, service LoadBalancer (IP attribuée par MetalLB) |
| `argocd` | ArgoCD v7.7.11 via Helm dans `argocd`, UI exposée en NodePort 30443 |

### Réseau et accès aux services

L'Ingress Controller NGINX reçoit une IP externe via MetalLB (première IP du pool : `192.168.1.140`). Les services applicatifs déployés par ArgoCD seront exposés via des Ingress avec certificats TLS Let's Encrypt automatiques.

| Service | FQDN | Méthode d'accès |
|---------|------|-----------------|
| ArgoCD | `argocd.k8s.thfx.fr` | Ingress (à migrer depuis NodePort) |
| Harbor | `harbor.k8s.thfx.fr` | Ingress |
| GitLab | `gitlab.k8s.thfx.fr` | Ingress |
| Jenkins | `jenkins.k8s.thfx.fr` | Ingress |
| SonarQube | `sonar.k8s.thfx.fr` | Ingress |

**Résolution DNS** :
- **Réseau local** : réécriture AdGuard `*.k8s.thfx.fr → 192.168.1.140`
- **Accès externe** (démo/jury) : enregistrement DNS OVH `*.k8s.thfx.fr → IP publique` + port-forward box 80/443 → 192.168.1.140

### Accès ArgoCD

L'UI ArgoCD est accessible via `https://<n'importe quel node>:30443`.
```bash
# Récupérer le mot de passe admin initial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

- **User** : `admin`
- **Mot de passe** : celui retourné par la commande ci-dessus

> Il est recommandé de changer le mot de passe après la première connexion via l'UI ou `argocd account update-password`.

## Kubeconfig

Le kubeconfig du cluster est récupéré depuis le control plane :

```bash
make kubeconfig
```

Le fichier est stocké dans `~/.kube/config-poc`. Les commandes `make` qui interagissent avec le cluster (`install-foundation`, `nodes`, `status`) utilisent automatiquement ce fichier.

Pour utiliser `kubectl` manuellement :

```bash
export KUBECONFIG=~/.kube/config-poc
kubectl get nodes
```

## Commandes utiles

```bash
make ping               # Vérifier la connectivité SSH vers les nodes
make nodes              # Lister les nodes du cluster
make status             # Statut complet (nodes + pods système + stockage)
make lint               # Linter les playbooks
make help               # Afficher toutes les commandes disponibles
```

## Notes

- **Machine de pilotage** : tous les playbooks sont lancés depuis la machine de dev (pas depuis le bastion)
- **Idempotence** : les playbooks peuvent être relancés sans risque (vérifications `stat` avant les opérations destructives)
- **SELinux** : activé en mode enforcing sur tous les nodes
- **Firewalld** : configuré avec les ports strictement nécessaires (pas de désactivation)
- **Secrets** : les credentials OVH sont dans `ansible/secrets.yml` (non versionné, voir `.gitignore`)
- **Stratégie de déploiement** : Ansible gère la fondation (infra de base), ArgoCD gère les services applicatifs (GitOps)