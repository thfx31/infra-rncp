# Documentation — cloud2/ (Scaleway)

Guide de mise en place du cluster K8s RNCP sur Scaleway.
Alternative à `cloud/` (OVH) — même stack K8s, provider cloud différent.

## Ordre de lecture recommandé

### Avant de commencer

1. **[scaleway-setup.md](scaleway-setup.md)** — Créer les credentials Scaleway
   (API keys, clé SSH, bucket remote state).
   *À faire une fois, avant tout.*

2. **[github-actions.md](github-actions.md)** — Configurer les GitHub Secrets
   et comprendre les workflows de déploiement.
   *À faire avant le premier déploiement.*

### Comprendre l'infrastructure

3. **[terraform.md](terraform.md)** — Variables Terraform, remote state S3,
   description des ressources Scaleway créées (instances, réseau, LB).

4. **[scaleway-lb.md](scaleway-lb.md)** — Comprendre le Load Balancer Scaleway
   provisionné automatiquement par le CCM.

5. **[scaleway-csi.md](scaleway-csi.md)** — Comprendre le stockage Block Storage
   Scaleway via le CSI driver.

6. **[ansible.md](ansible.md)** — Inventaire dynamique, playbooks, rôles.

### GitOps et CI/CD

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
1. Lire scaleway-setup.md  → créer les credentials
2. Lire github-actions.md  → configurer les secrets GitHub
3. Lancer workflow deploy   → Actions > Deploy K8s cluster (Scaleway) > Run workflow
4. Suivre configuration-manuelle.md → post-déploiement
```
