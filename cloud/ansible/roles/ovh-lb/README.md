# Rôle : ovh-lb

## Qu'est-ce que l'OVH Load Balancer ?

Un **Load Balancer** répartit le trafic entrant vers plusieurs serveurs backend.
Dans Kubernetes, les services de type `LoadBalancer` ont besoin d'une IP publique
externe pour être accessibles depuis internet.

**MetalLB** (utilisé dans proxmox/) gère ça en distribuant des IPs depuis un pool
local via le protocole L2 (ARP). Mais L2 ne fonctionne pas sur OVH car les
instances cloud sont sur des réseaux virtuels où l'ARP est filtré.

L'**OVH Load Balancer managé** est un service OVH qui :
- Fournit une IP publique stable
- Distribue le trafic vers les instances K8s (via le vRack)
- Est provisionné par Terraform dans `lb.tf`

```
Internet → IP publique OVH LB → vRack → NodePort K8s workers
```

## Intégration avec Kubernetes

Quand un service K8s est créé avec `type: LoadBalancer`, le cloud-controller-manager
OVH (déployé dans ce rôle) intercepte la création et configure automatiquement
le LB OVH pour router le trafic vers ce service.

Annotation utilisée :
```yaml
metadata:
  annotations:
    loadbalancer.ovh.com/type: "public"
```

## Ce que fait ce rôle

1. Déploie le **OVH Cloud Controller Manager** (CCM) dans le namespace `kube-system`
   → C'est lui qui fait le lien entre les services K8s et l'API OVH
2. Configure le `Secret` avec les credentials OVH (pour que le CCM appelle l'API)
3. Applique les labels de node nécessaires au CCM

## Relation avec Terraform

Le LB OVH est **provisionné par Terraform** (`terraform/lb.tf`) avant Ansible.
Ce rôle Ansible configure uniquement le cloud-controller-manager côté K8s
pour qu'il puisse gérer ce LB.

## Configuration

Fichier `defaults/main.yml` :
```yaml
ovh_ccm_version: "x.x.x"   # version du cloud-controller-manager OVH
ovh_region: "GRA11"
```

## Vérification post-déploiement

```bash
kubectl get pods -n kube-system | grep ovh    # pod CCM en Running
kubectl get svc -n ingress-nginx              # EXTERNAL-IP doit avoir l'IP du LB OVH
```
