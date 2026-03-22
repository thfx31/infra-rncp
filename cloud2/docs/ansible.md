# Ansible — cloud2/ (Scaleway)

## Inventaire dynamique

`inventory.py` génère l'inventaire depuis `tf_outputs.json` (produit par `terraform output -json`).

Noms des hosts :
- `scw-cp-01` — control plane
- `scw-worker-01` — worker 1
- `scw-worker-02` — worker 2

- **User SSH** : `almalinux` (image AlmaLinux 9 Scaleway)
- **Clé** : `~/.ssh/id_ed25519`

## Playbooks

| Playbook | Rôles | Description |
|----------|-------|-------------|
| `bootstrap-k8s.yml` | common, security, kubernetes-prereqs, containerd, kubeadm | OS + containerd + kubeadm |
| `init-cluster.yml` | cluster-init, cluster-join | kubeadm init + join |
| `install-foundation.yml` | cilium, scaleway-ccm, scaleway-csi, cert-manager, ingress-nginx, argocd | Stack fondation |

## Rôles spécifiques Scaleway

### `scaleway-ccm`
Installe le Scaleway Cloud Controller Manager.
Credentials injectés depuis les variables d'environnement `SCW_*`.

### `scaleway-csi`
Installe le driver CSI Block Storage Scaleway.
Mêmes credentials que le CCM.

## Rôles identiques à cloud/ (OVH)

Tous les rôles de bootstrap sont **copiés sans modification** depuis `cloud/` :
`common`, `security`, `kubernetes-prereqs`, `containerd`, `kubeadm`,
`cluster-init`, `cluster-join`, `cilium`, `cert-manager`, `ingress-nginx`, `argocd`

## Différences vs cloud/ (OVH)

| Aspect | OVH (cloud/) | Scaleway (cloud2/) |
|--------|--------------|--------------------|
| Hosts | `ovh-cp-01`, `ovh-worker-*` | `scw-cp-01`, `scw-worker-*` |
| Rôle LB | `ovh-lb` | `scaleway-ccm` |
| Rôle stockage | `cinder-csi` | `scaleway-csi` |
| Credentials cloud | `OS_*` env vars | `SCW_*` env vars |
| Prérequis nodes | `iscsi-initiator-utils` (iSCSI) | `iscsi-initiator-utils` (Block Storage) |
