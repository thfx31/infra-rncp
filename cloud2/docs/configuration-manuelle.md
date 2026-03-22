# Configuration manuelle — Tokens et credentials

Ce document décrit toutes les étapes de configuration manuelle nécessaires après le déploiement automatisé de l'infrastructure. Ces étapes ne sont pas automatisées car elles impliquent la génération de secrets qui ne doivent pas être stockés en clair dans le dépôt Git.

## Vue d'ensemble des tokens

| Service | Token | Utilisé par | Stocké dans |
|---------|-------|-------------|-------------|
| GitLab | Personal Access Token | `gitlab-init.sh` | Variable d'environnement locale |
| SonarQube | User Token | Jenkins (pipeline) | Credential Jenkins `sonarqube` |
| Harbor | Mot de passe admin | Jenkins (pipeline) | Credential Jenkins `harbor-credentials` |
| GitLab | Mot de passe root | Jenkins (pipeline) | Credential Jenkins `gitlab-credentials` |

---

## 0. Récupérer le kubeconfig

Après déploiement via GitHub Actions :

```bash
ssh -i ~/.ssh/id_ed25519 almalinux@<CP_IP> "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config-scw
export KUBECONFIG=~/.kube/config-scw
kubectl get nodes
```

L'IP du control plane est visible dans les outputs du job Terraform ou dans la console Scaleway.

---

## 1. Récupération des mots de passe initiaux

### Mot de passe GitLab root

GitLab génère un mot de passe root aléatoire au premier déploiement. Il est stocké dans un secret Kubernetes :

```bash
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
    -o jsonpath='{.data.password}' | base64 -d
```

> **Important** : Ce secret n'est pas supprimé automatiquement par le chart Helm GitLab (contrairement à ce que la documentation officielle indique). Il reste disponible pour consultation.

### Mot de passe Jenkins admin

```bash
kubectl -n jenkins get secret jenkins \
    -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

### Mot de passe Harbor admin

Défini dans le `values.yaml` du chart Harbor lors du déploiement ArgoCD. Par défaut dans ce POC : `Ch4ng3M3!`

---

## 2. Configuration SonarQube

### 2.1 Création du projet firmware-poc

1. Connecte-toi sur `https://sonarqube.k8s.yplank.fr` (admin / admin par défaut, à changer)
2. **Projects → Create project → Manually**
3. **Project key** : `firmware-poc`
4. **Display name** : `Firmware POC`
5. **Main branch** : `main`
6. Clique **Set up**
7. À l'étape "Set up CI", sélectionne **"With Jenkins"** puis **"Locally"**
8. À l'étape "New code definition", sélectionne **"Previous version"** → **Create project**

Répéter pour le second projet :
- **Project key** : `firmware-poc-modern`
- **Display name** : `Firmware POC Modern`

### 2.2 Génération du token SonarQube

1. Clique sur ton avatar en haut à droite → **My Account**
2. Onglet **Security**
3. **Generate Tokens** :
   - **Name** : `Jenkins`
   - **Type** : `User Token`
   - **Expires in** : `No expiration` (ou selon la politique de sécurité)
4. Clique **Generate**
5. **Copie le token immédiatement** — il ne sera plus affiché après fermeture de la page

---

## 3. Configuration des credentials Jenkins

Tous les credentials Jenkins se configurent dans **Manage Jenkins → Credentials → System → Global credentials → Add credentials**.

### 3.1 Credential Harbor

| Champ | Valeur |
|-------|--------|
| Kind | Username with password |
| Scope | Global |
| Username | `admin` |
| Password | `Ch4ng3M3!` (ou mot de passe Harbor configuré) |
| ID | `harbor-credentials` |
| Description | `Harbor registry credentials` |

### 3.2 Credential GitLab

| Champ | Valeur |
|-------|--------|
| Kind | Username with password |
| Scope | Global |
| Username | `root` |
| Password | Mot de passe root GitLab (voir section 1) |
| ID | `gitlab-credentials` |
| Description | `GitLab root credentials` |

### 3.3 Credential SonarQube

| Champ | Valeur |
|-------|--------|
| Kind | Secret text |
| Scope | Global |
| Secret | Token généré en section 2.2 |
| ID | `sonarqube` |
| Description | `SonarQube user token` |

---

## 4. Configuration du serveur SonarQube dans Jenkins

1. **Manage Jenkins → System**
2. Descends jusqu'à la section **SonarQube servers**
3. Coche **"Environment variables"**
4. Clique **Add SonarQube**

| Champ | Valeur |
|-------|--------|
| Name | `sonarqube` (**sensible à la casse**, doit correspondre exactement au nom dans le Jenkinsfile) |
| Server URL | `https://sonarqube.k8s.yplank.fr` |
| Server authentication token | Sélectionner le credential `sonarqube` |

5. **Save**

---

## 5. Création du projet Harbor

1. Connecte-toi sur `https://harbor.k8s.yplank.fr` (admin / Ch4ng3M3!)
2. **Projects → New Project**

| Champ | Valeur |
|-------|--------|
| Project Name | `poc-ci` |
| Access Level | Private |
| Storage Limit | -1 (illimité) |

3. **OK**

---

## 6. Initialisation du projet GitLab

Le script `gitlab-init.sh` automatise la création du groupe, du projet et le push du code source depuis GitHub.

```bash
./gitlab-init.sh
```

Le script effectue les opérations suivantes :
1. Attend que GitLab soit opérationnel (timeout 600s)
2. Récupère le mot de passe root depuis le secret Kubernetes
3. Obtient un token API via OAuth (Resource Owner Password Grant)
4. Crée le groupe `poc-ci` (idempotent)
5. Crée le projet `firmware-poc` (idempotent)
6. Désactive temporairement la protection de la branche `main`
7. Clone `infra-rncp` depuis GitHub et pousse `docker/firmware-poc/` sur GitLab
8. Réactive la protection de branche

> Le script utilise `git push --force` pour toujours refléter l'état de GitHub. Il peut être relancé autant de fois que nécessaire.

---

## 7. Création des pipelines Jenkins

### Pipeline firmware-poc (Ubuntu 18.04 + gcc-7)

1. Jenkins → **New Item**
2. Nom : `firmware-poc`, type : **Pipeline** → **OK**
3. Section **Pipeline** :

| Champ | Valeur |
|-------|--------|
| Definition | Pipeline script from SCM |
| SCM | Git |
| Repository URL | `https://gitlab.k8s.yplank.fr/poc-ci/firmware-poc.git` |
| Credentials | `gitlab-credentials` |
| Branch Specifier | `*/main` |
| Script Path | `Jenkinsfile` |

4. **Save**

### Pipeline firmware-poc-modern (Ubuntu 22.04 + gcc-12)

Même procédure avec :

| Champ | Valeur |
|-------|--------|
| Nom du job | `firmware-poc-modern` |
| Script Path | `Jenkinsfile.modern` |

---

## 8. Ordre de configuration recommandé

Pour une reconstruction complète de l'infrastructure (après redéploiement) :

1. Attendre que tous les pods soient `Running` : `kubectl get pods -A`
2. Récupérer les mots de passe (section 1)
3. Créer le projet Harbor `poc-ci` (section 5)
4. Créer les projets SonarQube et générer le token (section 2)
5. Configurer les credentials Jenkins (section 3)
6. Configurer le serveur SonarQube dans Jenkins (section 4)
7. Lancer `./gitlab-init.sh` (section 6)
8. Créer les deux pipelines Jenkins (section 7)
9. Lancer les builds manuellement
