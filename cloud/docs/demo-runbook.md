# Demo Runbook — OVH Public Cloud

## Prérequis

- Credentials OVH configurés (voir [ovh-setup.md](ovh-setup.md))
- GitHub Secrets configurés (voir [github-actions.md](github-actions.md))
- Cluster déployé via workflow `deploy`

## Étape 1 — Vérifier le cluster

```bash
# Via GitHub Actions
# Actions > Check cluster > Run workflow

# Ou en local
export KUBECONFIG=~/.kube/config-ovh
kubectl get nodes
kubectl -n argocd get applications
```

Résultat attendu : 3 nodes `Ready`, toutes les ArgoCD applications `Synced/Healthy`.

## Étape 2 — Accéder aux services

Récupérer les mots de passe initiaux :

```bash
# ArgoCD
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# GitLab
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab -o jsonpath='{.data.password}' | base64 -d

# Jenkins
kubectl get secret jenkins -n jenkins \
  -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

Services disponibles :
- https://argocd.k8s.yplank.fr
- https://gitlab.k8s.yplank.fr
- https://harbor.k8s.yplank.fr
- https://jenkins.k8s.yplank.fr
- https://sonarqube.k8s.yplank.fr
- https://grafana.k8s.yplank.fr

## Étape 3 — Déclencher le pipeline firmware

1. Se connecter à GitLab (root / mot de passe récupéré ci-dessus)
2. Aller dans le projet `poc-ci/firmware-poc`
3. Créer un commit sur la branche `main` (modifier un fichier source C)
4. Jenkins détecte le commit et lance le pipeline automatiquement

## Étape 4 — Vérifier les résultats CI/CD

- **Jenkins** : https://jenkins.k8s.yplank.fr → pipeline en cours/terminé
- **Harbor** : https://harbor.k8s.yplank.fr → image Docker publiée
- **SonarQube** : https://sonarqube.k8s.yplank.fr → rapport qualité du code C

## Étape 5 — Observer l'infrastructure

- **Grafana** : https://grafana.k8s.yplank.fr → métriques Prometheus (CPU, mémoire, réseau)
- **ArgoCD** : https://argocd.k8s.yplank.fr → état GitOps de toutes les applications

## Nettoyage post-démo

```bash
# Supprimer toute l'infrastructure OVH
# Actions > Destroy K8s cluster > Run workflow
# (nécessite approbation environment "production")

# Ou en local
make tf-destroy
```

⚠️ Penser à détruire les ressources OVH après la démo pour éviter les frais.
