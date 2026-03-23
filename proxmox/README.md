# Déploiement on-premise — Proxmox

Cluster Kubernetes kubeadm sur 3 VMs AlmaLinux 9 provisionnées sur Proxmox.
Piloté localement via `make`.

## Architecture

```
Proxmox Homelab
├── bastion             (Terraform, Ansible, kubectl)
└── Cluster K8s         (kubeadm, AlmaLinux 9)
    ├── rncp-cp-01          Control Plane
    ├── rncp-worker-01      Worker (GitLab, Harbor, agents Jenkins)
    └── rncp-worker-02      Worker (SonarQube, Jenkins, Monitoring)
```

| Nœud | IP | Rôle | CPU / RAM / Disque |
|------|----|------|--------------------|
| rncp-cp-01 | 192.168.x.120 | Control Plane | 4c / 8 GB / 80 GB |
| rncp-worker-01 | 192.168.x.121 | GitLab, Harbor | 4c / 10 GB / 150 GB |
| rncp-worker-02 | 192.168.x.122 | Jenkins, SonarQube, Monitoring | 4c / 10 GB / 150 GB |

## Démarrage rapide

```bash
# 1. Setup de l'environnement
make setup

# 2. Provisionner les VMs
make tf-apply

# 3. Tester la connectivité SSH
make ping

# 4. Bootstrap des nodes (OS, sécurité, containerd, kubeadm)
make bootstrap

# 5. Initialiser le cluster K8s
make init-cluster

# 6. Exporter le kubeconfig
make kubeconfig

# 7. Installer la fondation (Cilium, Longhorn, ArgoCD...)
make install-foundation

# Vérifier l'état
make check
```

Après le déploiement, une **configuration manuelle** est nécessaire :
voir [docs/configuration-manuelle.md](docs/configuration-manuelle.md).

```bash
# Initialiser le projet GitLab avec le code firmware
../gitlab-init.sh
```

## Prérequis

- Proxmox VE avec token API (`PROXMOX_VE_ENDPOINT`, `PROXMOX_VE_API_TOKEN`)
- Template AlmaLinux 9 — voir [docs/proxmox _template_almalinux.md](docs/proxmox%20_template_almalinux.md)
- Credentials OVH API pour le DNS challenge cert-manager — voir [docs/ansible.md](docs/ansible.md)
- Python 3 + `make setup`

## Documentation

### Infrastructure
- [Terraform — Provisionnement Proxmox](docs/terraform.md)
- [Ansible — Bootstrap & Fondation](docs/ansible.md)
- [ArgoCD & GitOps](docs/argocd_gitops.md)

### CI/CD
- [Pipeline CI/CD — Workflow et architecture](docs/cicd-workflow.md)
- [Configuration manuelle — Tokens et credentials](docs/configuration-manuelle.md)
- [POC vs Production — Justifications techniques](docs/poc-vs-production.md)
- [Runbook de démonstration](docs/demo-runbook.md)
