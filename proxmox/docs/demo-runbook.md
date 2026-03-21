# Runbook de démonstration

Ce document est la checklist opérationnelle pour le jour de la soutenance. Il couvre la vérification de l'infrastructure, le déroulé de la démo et les procédures de secours.

## Avant la soutenance (J-1)

### Vérification cluster homelab

```bash
# Tous les nœuds Ready
kubectl get nodes

# Tous les pods Running
kubectl get pods -A | grep -v Running | grep -v Completed

# Services accessibles
curl -sk https://gitlab.k8s.thfx.fr/-/readiness | python3 -m json.tool
curl -sk https://harbor.k8s.thfx.fr/api/v2.0/health | python3 -m json.tool
curl -sk https://jenkins.k8s.thfx.fr/login | grep -c "Jenkins"
curl -sk https://sonarqube.k8s.thfx.fr/api/system/status | python3 -m json.tool
```

### Vérification pipelines

1. Lancer un build `firmware-poc` → vérifier qu'il passe en vert
2. Lancer un build `firmware-poc-modern` → vérifier qu'il passe en vert
3. Vérifier la présence des images dans Harbor : `https://harbor.k8s.thfx.fr`

### Vérification ressources

```bash
# Utilisation mémoire par nœud
kubectl top nodes

# Pods les plus consommateurs
kubectl top pods -A --sort-by=memory | head -20
```

---

## Déroulé de la démonstration

### Étape 1 — Présentation de l'architecture (5 min)

Montrer le schéma d'architecture et expliquer :
- Le cluster Kubernetes (1 control plane + 2 workers)
- Les services déployés via ArgoCD (GitLab, Harbor, Jenkins, SonarQube)
- La séparation GitHub (infra) / GitLab (app)

**URL à ouvrir** :
- `https://argocd.k8s.thfx.fr` — montrer les applications déployées
- `https://grafana.k8s.thfx.fr` — montrer le monitoring du cluster

### Étape 2 — Présentation du code source (3 min)

Ouvrir `https://gitlab.k8s.thfx.fr/poc-ci/firmware-poc` et montrer :
- La structure du projet (src/, include/, Makefile)
- Le Jenkinsfile et ses 7 stages
- Expliquer que ce code représente un firmware embarqué réel (télémétrie, HAL, CRC)

### Étape 3 — Lancement du pipeline legacy (10 min)

1. Aller sur `https://jenkins.k8s.thfx.fr`
2. Ouvrir le job `firmware-poc`
3. Cliquer **Build Now**
4. Montrer le pod qui se crée : `kubectl get pods -n jenkins -w`
5. Commenter chaque stage en temps réel :
   - **Checkout** : récupération depuis GitLab
   - **Build image** : Ubuntu 18.04 + gcc-7 buildée dans DinD
   - **Trivy** : scan de vulnérabilités → 0 CVE (Ubuntu 18.04 EOL)
   - **Build firmware** : compilation C dans le conteneur legacy
   - **SonarQube** : analyse statique + Quality Gate
   - **Simulator** : validation ELF du binaire
   - **Push Harbor** : livraison de l'image validée
6. Montrer le résultat vert dans Stage View

### Étape 4 — Lancement du pipeline moderne (5 min)

1. Lancer `firmware-poc-modern`
2. Pointer la différence : Ubuntu 22.04 + gcc-12, `--ignore-unfixed` sur Trivy
3. Montrer les deux images dans Harbor à la fin

### Étape 5 — Résultats Harbor et SonarQube (3 min)

**Harbor** (`https://harbor.k8s.thfx.fr`) :
- Projet `poc-ci`
- Images taguées avec le hash de commit
- Historique des builds

**SonarQube** (`https://sonarqube.k8s.thfx.fr`) :
- Projet `firmware-poc` → metrics du code C
- Quality Gate passée
- Absence de bugs/code smells critiques

---

## Procédures de secours

### Le cluster homelab est inaccessible

Basculer sur le cluster OVH Cloud :

```bash
# Changer le kubeconfig
export KUBECONFIG=~/.kube/config-ovh

# Vérifier
kubectl get nodes

# Si l'infra OVH n'est pas déployée
cd terraform/ovh
terraform init
terraform apply

# Bootstrap cluster
cd ansible
ansible-playbook -i inventory-ovh.yml bootstrap-k8s.yml
ansible-playbook -i inventory-ovh.yml init-cluster.yml
ansible-playbook -i inventory-ovh.yml install-foundation.yml

# Déployer les services via ArgoCD (automatique après bootstrap)
# Puis configuration manuelle (voir docs/configuration-manuelle.md)
./gitlab-init.sh
```

### Un service spécifique est down

```bash
# Redémarrer un service via ArgoCD
kubectl annotate application <nom-app> -n argocd \
    argocd.argoproj.io/refresh=hard

# Forcer la resynchronisation
argocd app sync <nom-app>

# Vérifier les events
kubectl describe pod -n <namespace> <pod-name>
```

### Un build échoue pendant la démo

1. Vérifier les logs du stage en échec dans Jenkins
2. Si c'est un problème réseau (pull image) : relancer le build
3. Si c'est SonarQube : vérifier `kubectl get pods -n sonarqube`
4. Si c'est Harbor : vérifier `kubectl get pods -n harbor`

### Récupération des mots de passe

```bash
# GitLab root
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
    -o jsonpath='{.data.password}' | base64 -d

# Jenkins admin
kubectl -n jenkins get secret jenkins \
    -o jsonpath='{.data.jenkins-admin-password}' | base64 -d

# Harbor : défini dans le values.yaml ArgoCD (Ch4ng3M3!)
```

---

## Points de discussion attendus

### Pourquoi Kubernetes pour du CI/CD ?

Les agents Jenkins dynamiques (pods éphémères) permettent de scaler horizontalement le CI sans avoir de nodes dédiés en permanence. Chaque build dispose d'un environnement propre et isolé. L'infrastructure CI bénéficie des mêmes mécanismes de résilience que les applications (redémarrage automatique, scheduling).

### Pourquoi containeriser les environnements de build ?

Pour éliminer la dépendance à l'OS physique des nodes. Sans containerisation, chaque toolchain spécifique (gcc-7 sur Ubuntu 18.04) nécessite un node dédié ou une VM maintenue. Avec Docker, l'environnement de build est versionné, reproductible, et peut tourner sur n'importe quel node moderne.

### Qu'est-ce qui est livré dans Harbor ?

L'image de build validée — pas le firmware binaire. L'image est l'artefact car c'est elle qui encapsule l'environnement reproductible. En production, le firmware binaire serait également archivé dans un registry d'artefacts (Nexus, Artifactory) avec métadonnées (version, commit, date, résultats de tests).

### Pourquoi DinD et pas Kaniko ?

Les nodes utilisent containerd comme runtime (pas Docker), donc pas de socket Docker disponible. DinD est la solution pragmatique pour le POC. Kaniko serait utilisé en production car il ne nécessite pas de mode `privileged`.

### Comment garantir la traçabilité ?

Chaque image Harbor est taguée avec le hash Git du commit qui l'a produite. On peut donc retrouver exactement quel code source correspond à quelle image. En production, on ajouterait la signature Cosign pour garantir l'intégrité et l'origine de chaque image déployée.
