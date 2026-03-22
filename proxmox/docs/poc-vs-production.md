# POC vs Production — Justifications des choix techniques

Ce document présente les choix techniques retenus pour le POC et les alternatives recommandées en environnement de production. L'objectif est de démontrer la maîtrise des enjeux production tout en maintenant un POC réalisable sur homelab.

## Kubernetes

| Aspect | POC | Production |
|--------|-----|-----------|
| Distribution | kubeadm (vanilla) | RKE2 ou OpenShift |
| Topologie control plane | 1 nœud | 3 nœuds (HA) |
| OS des nœuds | AlmaLinux 9 | RHEL 9 ou Talos Linux (immutable, zéro SSH) |
| Accès nœuds | SSH | Bastion + accès restreint, SSH désactivé sur Talos |

**Justification kubeadm** : permet de comprendre et démontrer chaque étape du bootstrap Kubernetes (init, CNI, join). RKE2 serait préféré en production pour son hardening CIS intégré et son support entreprise.

## Stockage

| Aspect | POC | Production |
|--------|-----|-----------|
| Solution | Longhorn | Rook-Ceph ou stockage bare-metal dédié |
| Réplication | 1 replica (économie de ressources) | 3 replicas minimum |
| Backup | Non configuré | Velero + stockage objet on-premise |

**Justification Longhorn** : déploiement simple via Helm, interface web intuitive pour la démo. Rook-Ceph offrirait de meilleures performances et une vraie distribution des données en production, mais nécessite des nœuds dédiés et une configuration plus complexe.

## Réseau

| Aspect | POC | Production |
|--------|-----|-----------|
| CNI | Cilium | Cilium (identique) |
| Observabilité réseau | Hubble (activé) | Hubble + alerting |
| Service mesh | Non | Cilium mTLS ou Istio |
| Load balancer | MetalLB (L2) | MetalLB (BGP) ou solution hardware |

**Justification Cilium** : choix valide en production. eBPF-based, performances excellentes, politique réseau L7, observabilité intégrée via Hubble.

## Secrets

| Aspect | POC | Production |
|--------|-----|-----------|
| Solution | Sealed Secrets ou SOPS | HashiCorp Vault |
| Rotation des secrets | Manuelle | Automatique via Vault Agent |
| Audit | Non | Vault audit log |

**Justification** : HashiCorp Vault offre la gestion centralisée, la rotation automatique et l'audit trail des accès aux secrets, indispensables en production industrielle.

## Pipeline CI/CD

| Aspect | POC | Production |
|--------|-----|-----------|
| Build Docker | Docker-in-Docker (DinD) | Kaniko |
| Runtime nœuds | containerd | containerd (identique) |
| Agent Jenkins | Pod éphémère (identique) | Pod éphémère (identique) |

**Justification DinD** : les nœuds utilisent containerd comme runtime (pas Docker), donc le socket `/var/run/docker.sock` n'existe pas. DinD contourne cette limitation en lançant un daemon Docker dans le pod. L'inconvénient est le mode `privileged: true` requis par DinD, qui donne des droits étendus au pod.

En production, **Kaniko** est recommandé : il construit des images Docker sans daemon Docker et sans privilèges élevés, en lisant directement le Dockerfile et en poussant les layers vers le registry.

## Sécurité pipeline

| Composant | POC | Production |
|-----------|-----|-----------|
| Scan images | Trivy (dans pipeline) | Trivy + Harbor scanner intégré |
| Politique de blocage | `--exit-code 1` sur HIGH/CRITICAL | Admission controller (Kyverno/OPA) |
| Signature images | Non implémenté | Cosign + Sigstore |
| Analyse statique | SonarQube Community | SonarQube Enterprise + quality gates strictes |
| RBAC | Namespaces séparés | RBAC granulaire + audit logging |
| Network Policies | Cilium (configurées) | Cilium + mTLS inter-services |

**Sur Cosign** : la signature des images garantit que seules les images produites par le pipeline officiel peuvent être déployées. Un admission controller (Kyverno) vérifierait la signature avant tout déploiement. Non implémenté dans le POC par souci de simplicité, mais l'architecture est prête à l'accueillir.

## Observabilité

| Aspect | POC | Production |
|--------|-----|-----------|
| Métriques | Prometheus + Grafana | Idem + alerting PagerDuty/Opsgenie |
| Logs | Non centralisés | Loki ou ELK stack |
| Traces | Non | OpenTelemetry + Jaeger |
| Uptime | Non | Blackbox exporter |

## Haute disponibilité

Le POC utilise des réplicas uniques pour économiser les ressources homelab. En production :

- **GitLab** : déploiement HA avec PostgreSQL répliqué et Gitaly cluster
- **Harbor** : plusieurs replicas avec stockage objet partagé (MinIO ou Ceph RGW)
- **Jenkins** : controller en HA ou migration vers un système CI cloud-native
- **SonarQube** : cluster avec base PostgreSQL externe répliquée

## Infrastructure as Code

| Aspect | POC | Production |
|--------|-----|-----------|
| State Terraform | Fichier local | Backend S3 ou Terraform Cloud avec locking |
| Secrets Terraform | `terraform.tfvars` (gitignore) | Vault provider ou variables CI chiffrées |
| Pipeline IaC | Manuel | CI/CD dédié pour l'infra (GitOps IaC) |

## Résumé des points clés à l'oral

1. **DinD vs Kaniko** : DinD est fonctionnel mais nécessite `privileged: true`. En production on élimine ce vecteur d'attaque avec Kaniko.

2. **1 replica vs 3** : le dimensionnement POC est assumé et documenté. En production, la HA est non négociable pour les services critiques (GitLab, Harbor).

3. **kubeadm vs RKE2** : kubeadm démontre la maîtrise du bootstrap K8s. RKE2 apporterait le hardening CIS et le support entreprise.

4. **Cosign absent** : l'architecture est prête (Harbor supporte la vérification de signatures), la brique manquante est l'admission controller côté déploiement.

5. **Vault absent** : Sealed Secrets est suffisant pour un POC. Vault est incontournable en production pour la rotation automatique et l'audit trail.
