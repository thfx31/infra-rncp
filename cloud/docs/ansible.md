# Ansible — OVH Public Cloud

## Inventaire dynamique

Contrairement à `proxmox/` où l'inventaire est un fichier YAML statique,
`cloud/` utilise un **script Python dynamique** (`inventory.py`).

### Pourquoi ?

Les IPs des instances OVH ne sont connues qu'après `terraform apply`. Plutôt
que de les mettre à jour manuellement dans un fichier, `inventory.py` lit
les outputs Terraform et génère l'inventaire à la volée.

### Utilisation

```bash
make inventory                        # génère tf_outputs.json depuis terraform output
ansible -i inventory.py all --list-hosts  # vérifier l'inventaire
ansible -i inventory.py k8s_cluster -m ping
```

### Groupes d'hôtes

| Groupe | Hôtes | Utilisation |
|--------|-------|-------------|
| `control_plane` | ovh-cp-01 | kubeadm init |
| `workers` | ovh-worker-01, ovh-worker-02 | kubeadm join |
| `k8s_cluster` | tous | bootstrap OS |

## Connexion SSH

`ansible.cfg` utilise :
- **User** : `almalinux` (user par défaut de l'image AlmaLinux 9 OVH — différent de `admintf` dans proxmox/)
- **Clé** : `~/.ssh/id_ed25519` (ou variable `SSH_PRIVATE_KEY` dans GHA)

Dans GitHub Actions, la clé est écrite dans un fichier temporaire depuis le secret `SSH_PRIVATE_KEY`.

## Secrets

Tous les secrets sont passés via **variables d'environnement** injectées par GitHub Actions.
Aucun fichier `secrets.yml` n'est nécessaire (différent de `proxmox/`).

Les rôles qui ont besoin de credentials OVH/OpenStack (cert-manager, cinder-csi, ovh-lb)
lisent directement les variables d'environnement `OVH_*` et `OS_*`.

## Playbooks

| Playbook | Rôles | Description |
|----------|-------|-------------|
| `bootstrap-k8s.yml` | common, security, kubernetes-prereqs, containerd, kubeadm | Bootstrap OS + runtime |
| `init-cluster.yml` | cluster-init, cluster-join | Init kubeadm + join workers |
| `install-foundation.yml` | cilium, ovh-lb, cinder-csi, cert-manager, ingress-nginx, argocd | Stack fondation K8s |

## Différences vs proxmox/

| Aspect | proxmox/ | cloud/ |
|--------|----------|--------|
| Inventaire | `inventory.yml` statique | `inventory.py` dynamique |
| User SSH | `admintf` | `almalinux` (user OVH AlmaLinux 9) |
| Secrets | `secrets.yml` (gitignored) | Variables d'environnement |
| Rôle stockage | `longhorn` | `cinder-csi` |
| Rôle LB | `metallb` | `ovh-lb` |
| Rôle security | Hardening complet + firewall | Hardening OS minimal (réseau = Terraform) |
| Prérequis foundation | `iscsi-initiator-utils` dnf | `iscsi-initiator-utils` dnf (identique) |
