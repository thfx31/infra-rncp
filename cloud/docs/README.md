# Documentation — cloud/ (OVH Public Cloud)

Guide de mise en place du cluster K8s RNCP sur OVH Public Cloud.

## Ordre de lecture recommandé

### Avant de commencer

1. **[ovh-setup.md](ovh-setup.md)** — Créer les credentials OVH nécessaires
   (token API, user OpenStack, clé SSH, bucket remote state).
   *À faire une fois, avant tout.*

2. **[github-actions.md](github-actions.md)** — Configurer les GitHub Secrets
   et comprendre les workflows de déploiement.
   *À faire avant le premier déploiement.*

### Comprendre l'infrastructure

3. **[terraform.md](terraform.md)** — Variables Terraform, remote state S3,
   description des ressources OVH créées (instances, réseau, LB).

4. **[ovh-lb.md](ovh-lb.md)** — Comprendre le Load Balancer OVH managé
   (remplace MetalLB). *Nouveau concept vs proxmox/.*

5. **[cinder-csi.md](cinder-csi.md)** — Comprendre le stockage Cinder CSI
   (remplace Longhorn). *Nouveau concept vs proxmox/.*

6. **[ansible.md](ansible.md)** — Inventaire dynamique, playbooks, rôles adaptés OVH.

### GitOps et CI/CD (identiques à proxmox/)

7. **[argocd_gitops.md](argocd_gitops.md)** — Pattern App-of-Apps, déploiement
   des applications via ArgoCD.

8. **[cicd-workflow.md](cicd-workflow.md)** — Pipeline Jenkins, build firmware,
   Trivy, SonarQube.

### Post-déploiement

9. **[configuration-manuelle.md](configuration-manuelle.md)** — Étapes manuelles
   après déploiement (tokens SonarQube, credentials Jenkins, projet GitLab).

10. **[demo-runbook.md](demo-runbook.md)** — Scénario de démonstration complet.

---

## Séquence de déploiement résumée

```
1. Lire ovh-setup.md       → créer les credentials
2. Lire github-actions.md  → configurer les secrets GitHub
3. Lancer workflow deploy   → Actions > Deploy K8s cluster > Run workflow
4. Suivre configuration-manuelle.md → post-déploiement
5. Lancer workflow check    → vérifier l'état du cluster
```

Ou en local :
```bash
make setup && make tf-init && make tf-apply
make inventory && make ping && make bootstrap
make init-cluster && make kubeconfig
make install-foundation && make check
```
