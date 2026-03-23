# RNCP39582 — Expert en architecture des systèmes d'information
### Bloc de compétence BC05 — Concevoir et mettre en œuvre l'architecture d'un SI

Projet de Mastère **Expert en cloud, sécurité & infrastructure** — Modernisation d'une chaîne CI/CD industrielle avec Kubernetes, Infrastructure as Code et DevSecOps.

## Contexte

Ce projet propose une évolution de l'infrastructure CI/CD d'une entreprise du secteur spatial.
L'objectif est double :
- proposer une architecture unifiée pour plusieurs départements en modernisant l'infrastructure serveurs (VM vers Kubernetes)
- remplacer les nodes Jenkins sur OS obsolètes (CentOS 7, Ubuntu 18.04) par des environnements de build conteneurisés

## Deux déploiements, une même stack

| | [`proxmox/`](proxmox/README.md) | [`cloud/`](cloud/README.md) |
|---|---|---|
| **Infrastructure** | VMs Proxmox (on-premise) | Instances Scaleway Public Cloud |
| **Provisionnement** | Terraform `bpg/proxmox` | Terraform `scaleway/scaleway` |
| **Load Balancer** | MetalLB (bare-metal) | Scaleway CCM |
| **Stockage** | Longhorn | Scaleway Block Storage (CSI) |
| **Déploiement** | `make` + Ansible | GitHub Actions |
| **DNS** | domaine local | `*.k8s.yplank.fr` |

Les deux partagent la même **architecture et stack K8s**, mais disposent chacun d'un code Terraform et Ansible indépendant, adapté à leur provider.

## Stack technique

| Couche | Outil | Rôle |
|--------|-------|------|
| Provisionnement | Terraform | Création des VMs / instances cloud |
| Configuration | Ansible | Bootstrap OS, kubeadm, fondation K8s |
| Orchestration | Kubernetes (kubeadm) | Plateforme d'exécution |
| Réseau | Cilium + Hubble | CNI, observabilité réseau |
| Ingress | NGINX Ingress + cert-manager | Routage HTTPS, certificats Let's Encrypt |
| GitOps | ArgoCD (App-of-Apps) | Déploiement déclaratif des services |
| Source Control | GitLab | Code applicatif développeurs |
| CI/CD | Jenkins | Pipeline build/test/scan/livraison |
| Registry | Harbor | Stockage et scan d'images Docker |
| Qualité | SonarQube | Analyse statique du code C |
| Monitoring | Prometheus + Grafana | Métriques cluster et services |
| Sécurité | Trivy, RBAC, Cilium Network Policies | DevSecOps |

## Pipeline CI/CD

Le use-case métier est un firmware embarqué C compilé dans des environnements legacy conteneurisés. Le pipeline démontre qu'un node AlmaLinux 9 peut compiler dans un conteneur Ubuntu 18.04 + gcc-7 sans aucune dépendance à l'OS physique.

```
git push (GitLab)
    │
    ▼
Jenkins (pod Kubernetes éphémère)
    ├── 1. Checkout
    ├── 2. Build image Docker de build (Ubuntu 18.04 + gcc-7)
    ├── 3. Scan Trivy — FAIL si vulnérabilités HIGH/CRITICAL
    ├── 4. Compilation firmware dans le conteneur legacy
    ├── 5. Analyse SonarQube + Quality Gate
    ├── 6. Validation simulateur ELF
    └── 7. Push image validée sur Harbor
```

Deux pipelines parallèles :

| Job | Environnement | Image Harbor |
|-----|--------------|-------------|
| `firmware-poc` | Ubuntu 18.04 + gcc-7 | `poc-ci/build-legacy-ubuntu18` |
| `firmware-poc-modern` | Ubuntu 22.04 + gcc-12 | `poc-ci/build-modern-ubuntu22` |

## Structure du dépôt

```
infra-rncp/
├── proxmox/                Déploiement on-premise (Proxmox)
│   ├── terraform/          Provisionnement VMs
│   ├── ansible/            Bootstrap et fondation K8s
│   ├── kubernetes/apps/    Applications ArgoCD
│   ├── docker/             Images de build firmware + code source C
│   ├── docs/               Documentation technique
│   └── Makefile            Commandes de pilotage
├── cloud/                  Déploiement cloud (Scaleway)
│   ├── terraform/          Provisionnement instances Scaleway
│   ├── ansible/            Bootstrap et fondation K8s
│   ├── kubernetes/apps/    Applications ArgoCD
│   └── docs/               Documentation technique
└── .github/workflows/      GitHub Actions (déploiement cloud)
```

## Démarrage rapide

→ **On-premise (Proxmox)** : voir [proxmox/README.md](proxmox/README.md)

→ **Cloud (Scaleway)** : voir [cloud/README.md](cloud/README.md)
