# Déploiement cloud — Scaleway

Cluster Kubernetes kubeadm sur 3 instances AlmaLinux 9 sur Scaleway Public Cloud.
Déploiement entièrement automatisé via GitHub Actions.

## Architecture

```
Scaleway Public Cloud (fr-par-2)
├── Load Balancer Scaleway       (provisionné automatiquement par le CCM)
└── Cluster K8s                  (kubeadm, AlmaLinux 9)
    ├── rncp-scw-cp-01           Control Plane (DEV1-L — 4c / 8 GB / 40 GB)
    ├── rncp-scw-worker-01       Worker — GitLab, Harbor (DEV1-XL — 4c / 12 GB / 80 GB)
    └── rncp-scw-worker-02       Worker — Jenkins, SonarQube, Monitoring (DEV1-XL)
```

## Déploiement

Le déploiement est piloté par **GitHub Actions** :

1. **[Actions → Deploy K8s cluster (Scaleway)](../../.github/workflows/deploy-cloud.yml)** — Terraform + Ansible + fondation K8s + ArgoCD
2. ArgoCD déploie automatiquement les applications depuis `kubernetes/apps/`
3. Suivre [docs/configuration-manuelle.md](docs/configuration-manuelle.md) pour la configuration post-déploiement

## Prérequis

- Credentials Scaleway — voir [docs/scaleway-setup.md](docs/scaleway-setup.md)
- Credentials OVH API (DNS challenge cert-manager) — voir [docs/ovh-api.md](docs/ovh-api.md)
- GitHub Secrets configurés — voir [docs/github-actions.md](docs/github-actions.md)

## Services déployés

| Service | URL |
|---------|-----|
| ArgoCD | https://argocd.k8s.yplank.fr |
| GitLab | https://gitlab.k8s.yplank.fr |
| Harbor | https://harbor.k8s.yplank.fr |
| Jenkins | https://jenkins.k8s.yplank.fr |
| SonarQube | https://sonarqube.k8s.yplank.fr |
| Grafana | https://grafana.k8s.yplank.fr |

## Documentation

### Mise en place
- [Scaleway — Credentials et prérequis](docs/scaleway-setup.md)
- [GitHub Actions — Workflows de déploiement](docs/github-actions.md)
- [OVH API — DNS challenge cert-manager](docs/ovh-api.md)

### Infrastructure
- [Terraform — Ressources Scaleway](docs/terraform.md)
- [Ansible — Bootstrap & Fondation](docs/ansible.md)
- [Load Balancer Scaleway](docs/scaleway-lb.md)
- [Block Storage CSI](docs/scaleway-csi.md)
- [ArgoCD & GitOps](docs/argocd_gitops.md)

### CI/CD
- [Pipeline CI/CD — Workflow et architecture](docs/cicd-workflow.md)
- [Configuration manuelle — Tokens et credentials](docs/configuration-manuelle.md)
- [Runbook de démonstration](docs/demo-runbook.md)
