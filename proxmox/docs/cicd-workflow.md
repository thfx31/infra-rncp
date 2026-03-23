# Pipeline CI/CD — Workflow et Architecture

## Vue d'ensemble

Le pipeline CI/CD automatise la compilation, la validation et la livraison des environnements de build pour le firmware embarqué. Il repose sur Jenkins déployé sur Kubernetes, avec GitLab comme dépôt de code source et Harbor comme registry d'images Docker.

```
Développeur
    │
    │ git push
    ▼
GitLab (poc-ci/firmware-poc)
    │
    │ déclenchement manuel (ou webhook)
    ▼
Jenkins (pod Kubernetes éphémère)
    │
    ├── 1. Checkout
    ├── 2. Build image Docker de build
    ├── 3. Scan Trivy
    ├── 4. Compilation firmware dans le conteneur
    ├── 5. Analyse SonarQube
    ├── 6. Validation simulateur ELF
    └── 7. Push image validée sur Harbor
```

## Architecture du pod Jenkins

À chaque build, Jenkins crée un **Pod Kubernetes éphémère** contenant trois conteneurs :

| Conteneur | Image | Rôle |
|-----------|-------|------|
| `dind` | `docker:24-dind` | Daemon Docker (Docker-in-Docker) |
| `builder` | `docker:24-cli` | Exécution des stages du pipeline |
| `trivy` | `aquasec/trivy:latest` | Scan de vulnérabilités |

Le conteneur `builder` se connecte au daemon `dind` via `DOCKER_HOST=tcp://localhost:2375`. Le pod est détruit automatiquement à la fin du build.

> **Note POC** : L'approche Docker-in-Docker est utilisée car le runtime des nodes est containerd (pas Docker). En production, on utiliserait Kaniko pour des builds sans daemon Docker privilégié.

## Détail des stages

### Stage 1 — Checkout

Récupère le code depuis GitLab avec les credentials `gitlab-credentials`. Configure `git safe.directory` pour éviter les erreurs de propriété dans le contexte Kubernetes.

Extrait le hash court du commit (`git rev-parse --short HEAD`) qui servira de tag pour l'image Docker produite.

### Stage 2 — Build Docker image

Construit l'image de l'environnement de build legacy (`build-legacy-ubuntu18`) ou moderne (`build-modern-ubuntu22`).

**Logique de rebuild intelligente** : le stage vérifie si le Dockerfile a été modifié depuis le commit précédent (`git diff HEAD~1 HEAD`). Si le Dockerfile est inchangé, il tente de puller l'image existante depuis Harbor plutôt que de rebuilder. Un rebuild est forcé dans trois cas :
- Le Dockerfile a été modifié
- L'image n'existe pas encore sur Harbor
- C'est le premier build du job

L'image est taguée avec le hash du commit (`image:abc1234`) et `image:latest`.

### Stage 3 — Trivy scan

Scanne l'image Docker construite à la recherche de vulnérabilités CVE.

| Job | Comportement |
|-----|-------------|
| `firmware-poc` (Ubuntu 18.04) | Bloque sur HIGH et CRITICAL |
| `firmware-poc-modern` (Ubuntu 22.04) | Bloque sur HIGH et CRITICAL avec `--ignore-unfixed` |

La différence de configuration est justifiée : Ubuntu 18.04 étant en fin de vie, Trivy ne référence plus de nouvelles CVEs. Ubuntu 22.04 étant activement maintenu, certaines vulnérabilités connues n'ont pas encore de correctif disponible — `--ignore-unfixed` évite de bloquer sur des CVEs non corrigeables.

En cas d'échec, un rapport JSON est archivé dans Jenkins (`trivy-report.json`).

### Stage 4 — Build firmware

Compile le firmware C dans le conteneur de build approprié. Le node Jenkins tourne sur **AlmaLinux 9** mais la compilation s'effectue dans un conteneur **Ubuntu 18.04 + gcc-7** — c'est le use-case central du POC : éliminer la dépendance à l'OS physique pour les toolchains legacy.

```bash
docker run --rm \
    -v $(pwd):/workspace \
    -w /workspace \
    harbor.k8s.homelab.example/poc-ci/build-legacy-ubuntu18:latest \
    make TARGET=x86 clean all
```

Le Makefile produit `build/firmware.elf`. Le stage vérifie la présence du binaire avant de continuer.

### Stage 5 — SonarQube analysis

Lance l'analyse statique du code C via le scanner SonarQube dans un conteneur Docker. Le token d'authentification est injecté depuis les credentials Jenkins.

```bash
docker run --rm \
    -e SONAR_HOST_URL=https://sonarqube.k8s.homelab.example \
    -e SONAR_TOKEN=${SONAR_TOKEN} \
    -v $(pwd):/usr/src \
    sonarsource/sonar-scanner-cli:latest \
    -Dsonar.projectKey=firmware-poc \
    -Dsonar.sources=/usr/src/src \
    -Dsonar.language=c \
    -Dsonar.qualitygate.wait=true
```

Le paramètre `-Dsonar.qualitygate.wait=true` fait attendre le scanner jusqu'au résultat de la Quality Gate. Le pipeline échoue si la Quality Gate n'est pas satisfaite.

> **Choix technique** : L'intégration native Jenkins-SonarQube (`withSonarQubeEnv` + `waitForQualityGate`) ne fonctionne pas lorsque le scanner tourne dans un `docker run` — Jenkins ne peut pas intercepter les métadonnées produites à l'intérieur d'un conteneur fils. Le paramètre `qualitygate.wait` dans le scanner lui-même contourne cette limitation.

### Stage 6 — Simulator

Valide le binaire ELF produit avec un simulateur custom compilé à l'intérieur de l'image de build. Le simulateur vérifie :
- Magic bytes ELF (support ELF32 et ELF64)
- Taille du binaire (512 octets — 512 Ko)
- Architecture cible (x86, x86-64, ARM, AArch64)
- Présence de code exécutable (segment PT_LOAD avec flag PF_X)
- Entry point non nul

Exit code 0 = PASS, exit code 1 = FAIL. Un échec ici indique un problème de compilation ou de corruption du binaire.

### Stage 7 — Push Harbor

Pousse l'image validée sur Harbor avec deux tags :
- `image:abc1234` — tag immuable lié au commit Git
- `image:latest` — tag flottant pour référence courante

L'image n'est poussée que si **tous les stages précédents ont réussi**, garantissant que seules les images validées (scan Trivy OK + Quality Gate OK + firmware compilable + binaire valide) atterrissent dans Harbor.

## Post-actions

Après chaque build (succès ou échec) :
- Suppression des images Docker locales du pod pour libérer de l'espace
- Déconnexion du registry Harbor

## Projets Jenkins

| Job | Dockerfile | Image Harbor | SonarQube project |
|-----|-----------|-------------|------------------|
| `firmware-poc` | `docker/Dockerfile.legacy` | `poc-ci/build-legacy-ubuntu18` | `firmware-poc` |
| `firmware-poc-modern` | `docker/Dockerfile.modern` | `poc-ci/build-modern-ubuntu22` | `firmware-poc-modern` |

Les deux jobs partagent le même code source firmware et la même logique de pipeline — seuls l'image cible et le Dockerfile diffèrent.

## Séparation des dépôts

| Dépôt | Contenu | Usage |
|-------|---------|-------|
| GitHub (`infra-rncp`) | Terraform, Ansible, manifestes K8s, Dockerfiles, Jenkinsfile | Code d'infrastructure, géré par l'équipe infra |
| GitLab (cluster K8s) | Code C firmware, Makefile, Jenkinsfile | Code applicatif, poussé par les développeurs |

Le script `gitlab-init.sh` synchronise le contenu de `docker/firmware-poc/` depuis GitHub vers GitLab. En production, les développeurs pousseraient directement sur GitLab.
