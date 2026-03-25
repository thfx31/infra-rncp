# Demo Runbook — Scaleway

## Prérequis

- Credentials Scaleway configurés (voir [scaleway-setup.md](scaleway-setup.md))
- GitHub Secrets configurés (voir [github-actions.md](github-actions.md))
- Cluster déployé via workflow `deploy-cloud`

## Étape 1 — Vérifier le cluster

```bash
# Récupérer le kubeconfig
ssh -i ~/.ssh/id_ed25519 almalinux@<CP_IP> "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config-scw
export KUBECONFIG=~/.kube/config-scw

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

# Jenkins (login: admin / Ch4ng3M3!)

# Grafana (login: admin / Ch4ng3M3!)

# Harbor (login: admin)
# Mot de passe défini dans le chart : Ch4ng3M3!

# SonarQube (login: admin / admin — changement forcé à la première connexion)
```

Services disponibles :
- https://argocd.k8s.yplank.fr — admin / (secret argocd-initial-admin-secret)
- https://gitlab.k8s.yplank.fr — root / (secret gitlab-gitlab-initial-root-password)
- https://harbor.k8s.yplank.fr — admin / Ch4ng3M3!
- https://jenkins.k8s.yplank.fr — admin / Ch4ng3M3!
- https://sonarqube.k8s.yplank.fr — admin / admin (à changer à la première connexion)
- https://grafana.k8s.yplank.fr — admin / Ch4ng3M3!

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

## Configuration DNS

Récupérer l'IP du Load Balancer Scaleway :

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Créer un enregistrement DNS wildcard dans la zone `yplank.fr` (espace client OVH) :

```
*.k8s.yplank.fr  →  A  →  <IP_LB>
```

## Accès sans DNS (port-forward)

Pour tester sans configurer le DNS :

```bash
# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
# → https://localhost:8080

# Accès direct via IP LB (ajouter dans /etc/hosts)
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$LB_IP argocd.k8s.yplank.fr gitlab.k8s.yplank.fr harbor.k8s.yplank.fr \
  jenkins.k8s.yplank.fr sonarqube.k8s.yplank.fr grafana.k8s.yplank.fr" \
  | sudo tee -a /etc/hosts
```

## Vérifier le Load Balancer Scaleway

```bash
# IP publique du LB (à utiliser pour le DNS *.k8s.yplank.fr)
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Pods CCM
kubectl get pods -n kube-system | grep scaleway-cloud-controller

# Pods CSI
kubectl get pods -n kube-system | grep scaleway-csi
```

## Problèmes connus et résolutions rapides

### Certificat TLS non émis après déploiement

**Symptôme** : un ou plusieurs services affichent une erreur TLS dans le navigateur.
cert-manager peut échouer avec `404 Certificate not found` lors de la finalisation
de l'ordre ACME — erreur transitoire côté Let's Encrypt, souvent causée par plusieurs
certificats demandés simultanément au déploiement.

**Diagnostic** :
```bash
kubectl get certificate -A
kubectl describe certificate -n <namespace> <nom-cert>
```

**Résolution** — supprimer le Certificate pour forcer un retry complet :
```bash
kubectl delete certificate -n <namespace> <nom-cert>
# cert-manager le recrée automatiquement (~1 minute)
kubectl get certificate -n <namespace> -w
```

**Cas fréquents** : `gitlab-webservice-tls` (namespace `gitlab`), `harbor-tls` (namespace `harbor`).

---

## Nettoyage post-démo

```bash
# Supprimer toute l'infrastructure Scaleway
# Actions > Deploy K8s cluster (Scaleway) > (pas de workflow destroy séparé)

# Ou via la CLI gh
gh workflow run deploy-cloud.yml

# Destroy via Terraform en local
cd cloud/terraform
terraform destroy
```
