# Ansible — Bootstrap & Fondation Kubernetes

## Prérequis

- Python 3.x installé sur la machine de dev
- Accès SSH par clé vers les nodes K8s (user `admintf`, sudo sans mot de passe)
- Résolution DNS des hostnames `cp-01`, `worker-01`, `worker-02`
- `kubectl` et `helm` installés localement (pour les playbooks fondation)

## Setup de l'environnement

Depuis la racine du dépôt :

```bash
# Installation complète (virtualenv + dépendances Python + collections Ansible)
make setup

# Activer le virtualenv
source ~/.virtualenvs/ansible/bin/activate
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
| `control_plane` | `cp-01` | Node control plane Kubernetes |
| `workers` | `worker-01`, `worker-02` | Nodes worker Kubernetes |
| `k8s_cluster` | tous | Groupe parent pour les playbooks de bootstrap |

La résolution des hostnames se fait par DNS. Les variables de connexion (`remote_user`, `become`, `private_key_file`) sont centralisées dans `ansible/ansible.cfg`.

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

Installe les composants infrastructure sur le cluster. Nécessite le kubeconfig.

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
| `longhorn` | Stockage distribué Longhorn v1.7.2 via Helm dans `longhorn-system`, 2 réplicas par volume |

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
make ping       # Vérifier la connectivité SSH vers les nodes
make nodes      # Lister les nodes du cluster
make status     # Statut complet (nodes + pods système + stockage)
make lint       # Linter les playbooks
make help       # Afficher toutes les commandes disponibles
```

## Notes

- **Machine de pilotage** : tous les playbooks sont lancés depuis la machine de dev (pas depuis le bastion)
- **Idempotence** : les playbooks peuvent être relancés sans risque (vérifications `stat` avant les opérations destructives)
- **SELinux** : activé en mode enforcing sur tous les nodes
- **Firewalld** : configuré avec les ports strictement nécessaires (pas de désactivation)
