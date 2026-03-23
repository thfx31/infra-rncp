# ArgoCD & GitOps — Guide du projet

## Vue d'ensemble

ArgoCD est déployé sur le cluster Kubernetes et gère le déploiement de tous les services via le pattern **App-of-Apps**. Chaque service est déclaré dans un fichier YAML dans le dépôt GitHub, et ArgoCD synchronise automatiquement l'état du cluster avec le dépôt.

## Architecture GitOps

```
GitHub (infra-rncp)
  └── kubernetes/
       ├── argocd/
       │    ├── ingress.yaml          ← Ingress ArgoCD (cert-manager TLS)
       │    └── app-of-apps.yaml      ← Application racine
       └── apps/
            ├── harbor.yaml           ← Helm chart Harbor
            ├── gitlab.yaml           ← Helm chart GitLab
            ├── jenkins.yaml          ← Helm chart Jenkins
            ├── sonarqube.yaml        ← Helm chart SonarQube
            ├── monitoring.yaml       ← Helm chart kube-prometheus-stack
            └── metrics-server.yaml   ← Helm chart metrics-server
```

**Principe** : ArgoCD surveille le dossier `kubernetes/apps/` sur la branche `main`. Tout fichier Application ajouté dans ce dossier est automatiquement déployé sur le cluster.

## Pattern App-of-Apps

L'Application racine (`app-of-apps.yaml`) pointe vers le dossier `kubernetes/apps/` et déploie toutes les Applications enfants :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/thfx31/infra-rncp.git
    targetRevision: main
    path: kubernetes/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true      # Supprime les ressources qui ne sont plus dans Git
      selfHeal: true    # Restaure l'état si modifié manuellement
```

Chaque Application enfant pointe vers un **Helm chart distant** avec des valeurs personnalisées (`valuesObject`).

## Services déployés

| Service | URL | Chart Helm | Namespace |
|---------|-----|------------|-----------|
| ArgoCD | https://argocd.k8s.yplank.fr | Déployé manuellement (Helm) | `argocd` |
| Harbor | https://harbor.k8s.yplank.fr | `helm.goharbor.io/harbor` | `harbor` |
| GitLab | https://gitlab.k8s.yplank.fr | `charts.gitlab.io/gitlab` | `gitlab` |
| Jenkins | https://jenkins.k8s.yplank.fr | `charts.jenkins.io/jenkins` | `jenkins` |
| SonarQube | https://sonarqube.k8s.yplank.fr | `sonarsource.github.io/.../sonarqube` | `sonarqube` |
| Grafana | https://grafana.k8s.yplank.fr | `prometheus-community/.../kube-prometheus-stack` | `monitoring` |
| Metrics Server | — (API interne) | `kubernetes-sigs/.../metrics-server` | `kube-system` |

## Flux de travail quotidien

### Ajouter un nouveau service

1. Créer `kubernetes/apps/<service>.yaml` avec la définition Application ArgoCD
2. Commit + push sur `main`
3. ArgoCD détecte le changement (polling 3 min) et déploie automatiquement

### Modifier la configuration d'un service

1. Modifier les `valuesObject` dans `kubernetes/apps/<service>.yaml`
2. Commit + push sur `main`
3. ArgoCD applique les modifications automatiquement

### Forcer un refresh immédiat

Via l'UI : ouvrir https://argocd.k8s.yplank.fr → cliquer **Refresh** sur l'application.

Via CLI :
```bash
kubectl -n argocd patch application app-of-apps \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Vérifier l'état des applications

```bash
kubectl -n argocd get applications
```

## Gestion des certificats TLS

Tous les Ingress utilisent **cert-manager** avec le ClusterIssuer `letsencrypt-prod`. L'annotation suivante sur les Ingress déclenche automatiquement la création du certificat :

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```

Chaque service doit avoir un `secretName` TLS unique pour éviter les conflits de certificat.

## DNS

Tous les sous-domaines `*.k8s.yplank.fr` pointent vers l'IP publique du Load Balancer
Scaleway (provisionnée automatiquement par le CCM lors du déploiement d'ingress-nginx).

Récupérer l'IP LB :
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
