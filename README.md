# RNCP39582 - Expert en architecture des systèmes d’information 
### Bloc de compétence RNCP39582BC05 - Concevoir et mettre en oeuvre l'architecture d'un SI

Projet de Mastère **Expert en cloud, sécurité & infrastructure** — Modernisation d'une chaîne CI/CD industrielle avec Kubernetes, Infrastructure as Code et DevSecOps.

## Contexte

Ce projet propose une évolution de l'infrastructure CI/CD d'une entreprise du secteur spatial.
L'objectif est double :
- proposer une architecture unifiée pour plusieurs département en modernisant l'infrastructure serveurs (VM vers Kubernetes)
- remplacer les nodes Jenkins sur OS obsolètes (CentOS 7, Ubuntu 18.04) par des environnements de build conteneurisés


## Architecture

```
Proxmox Homelab
├── bastion         (Terraform, Ansible, kubectl)
└── Cluster K8s     (kubeadm, AlmaLinux 9)
    ├── rncp-cp-01      Control Plane
    ├── rncp-worker-01  Worker (GitLab, Harbor, agents Jenkins)
    └── rncp-worker-02  Worker (SonarQube, Jenkins, Monitoring)
```

## Stack technique

| Couche | Outil | Rôle |
|--------|-------|------|
| Provisionnement | Terraform | Création des VM sur Proxmox |
| Configuration | Ansible | Bootstrap OS, kubeadm, fondation K8s |
| Orchestration | Kubernetes (kubeadm) | Plateforme d'exécution |
| Réseau | Cilium + Hubble | CNI, observabilité réseau |
| Stockage | Longhorn | Stockage distribué persistant |
| Load Balancing | MetalLB | IP externes bare-metal |
| Ingress | NGINX Ingress + cert-manager | Routage HTTPS, certificats Let's Encrypt |
| GitOps | ArgoCD (App-of-Apps) | Déploiement déclaratif des services |
| Source Control | GitLab (sur K8s) | Code applicatif développeurs |
| CI/CD | Jenkins (sur K8s) | Pipeline build/test/scan/sign |
| Registry | Harbor | Stockage et scan d'images Docker |
| Qualité | SonarQube | Analyse statique du code C |
| Monitoring | Prometheus + Grafana | Métriques cluster et services |
| Sécurité | Trivy, Cosign, RBAC, Network Policies | DevSecOps |

## Structure du dépôt

```
infra-rncp/
├── terraform/              Provisionnement VM Proxmox
├── ansible/                Bootstrap et fondation K8s
│   ├── bootstrap-k8s.yml       OS, sécurité, containerd, kubeadm
│   ├── init-cluster.yml        kubeadm init + join + labels
│   ├── install-foundation.yml  Cilium, Longhorn, MetalLB, cert-manager, ArgoCD
│   └── roles/
├── kubernetes/
│   └── apps/               Applications ArgoCD (App-of-Apps)
│       ├── gitlab.yaml
│       ├── harbor.yaml
│       ├── jenkins.yaml
│       ├── sonarqube.yaml
│       ├── monitoring.yaml
│       └── metrics-server.yaml
├── docs/                   Documentation technique
├── Makefile                Commandes de pilotage
└── get-password.sh         Mots de passe des services
```

## Démarrage rapide

```bash
# 1. Setup de l'environnement de dev
make setup

# 2. Provisionner les VM
make tf-apply

# 3. Tester la connectivité SSH
make ping

# 4. Bootstrap des nodes (OS, sécurité, containerd, kubeadm)
make bootstrap

# 5. Initialiser le cluster K8s (kubeadm init + join)
make init-cluster

# 6. Exporter et charger le kubeconfig
make kubeconfig

# 7. Installer la fondation (Cilium, Longhorn, ArgoCD...)
make install-foundation

# 7. ArgoCD déploie automatiquement les services depuis kubernetes/apps/
# Vérifier l'état :
make check
```

## Services déployés

| Service | URL |
|---------|-----|
| ArgoCD | https://argocd.k8s.thfx.fr |
| GitLab | https://gitlab.k8s.thfx.fr |
| Harbor | https://harbor.k8s.thfx.fr |
| Jenkins | https://jenkins.k8s.thfx.fr |
| SonarQube | https://sonarqube.k8s.thfx.fr |
| Grafana | https://grafana.k8s.thfx.fr |

## Documentation

- [Terraform — Provisionnement Proxmox](docs/terraform.md)
- [Ansible — Bootstrap & Fondation](docs/ansible.md)
- [ArgoCD & GitOps](docs/argocd_gitops.md)
- [Proxmox — Template AlmaLinux](docs/proxmox%20_template_almalinux.md)
