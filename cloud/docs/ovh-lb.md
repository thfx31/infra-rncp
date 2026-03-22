# OVH Load Balancer — Exposition des services K8s

## Contexte

Dans `proxmox/`, **MetalLB** distribue des IPs depuis un pool local via le
protocole L2 (ARP). Il annonce "c'est moi qui réponds à cette IP" sur le réseau.

Sur OVH, ce mécanisme ne fonctionne pas : les instances cloud sont sur des
réseaux virtuels où l'ARP est filtré par OVH pour des raisons de sécurité.
On utilise à la place l'**OVH Load Balancer managé**.

## Architecture

```
Internet
    ↓
IP publique OVH LB (ex: 51.68.xx.xx)
    ↓ (forward vers NodePort)
vRack OVH (réseau privé 10.0.0.x)
    ↓
NodePort K8s (ex: port 30080 sur worker-01 et worker-02)
    ↓
Service NGINX Ingress
    ↓
Pods applicatifs (GitLab, Harbor, Jenkins...)
```

## Deux composants à comprendre

### 1. OVH Load Balancer (côté OVH)

Provisionné par **Terraform** dans `terraform/lb.tf`. C'est une ressource OVH
qui existe indépendamment du cluster K8s. Il a une IP publique fixe et forward
le trafic HTTP/HTTPS (ports 80/443) vers les instances worker.

### 2. OVH Cloud Controller Manager (côté K8s)

Déployé par le rôle Ansible **`ovh-lb`** dans le namespace `kube-system`.
C'est un composant K8s qui "parle" à l'API OVH. Son rôle :
- Surveiller les services K8s de type `LoadBalancer`
- Automatiquement configurer le LB OVH pour router vers ces services
- Mettre à jour le champ `EXTERNAL-IP` du service avec l'IP du LB

## Flux de création d'un service LoadBalancer

```
kubectl apply (service type: LoadBalancer)
        ↓
Cloud Controller Manager détecte le nouveau service
        ↓
Appelle API OVH → configure une règle sur le LB existant
        ↓
kubectl get svc → EXTERNAL-IP = IP du LB OVH
```

## Dans ce projet

Un seul LB OVH est créé. Il route tout le trafic 80/443 vers le service
`ingress-nginx`. Nginx Ingress route ensuite vers les bons services selon
le `host` de la requête :
- `gitlab.k8s.yplank.fr` → GitLab
- `harbor.k8s.yplank.fr` → Harbor
- etc.

## Coût

L'OVH Load Balancer est une ressource payante (~quelques euros/mois selon la config).
Penser à le détruire avec `make tf-destroy` ou le workflow `destroy` quand le POC
n'est pas utilisé.

## Déploiement

- **Terraform** : `terraform/lb.tf` — provisionnement du LB OVH
- **Ansible** : `ansible/roles/ovh-lb/` — déploiement du Cloud Controller Manager

Voir le README du rôle `ovh-lb/` pour les détails de configuration.
