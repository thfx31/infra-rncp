# Scaleway Load Balancer (CCM)

## Rôle

Le **Scaleway Cloud Controller Manager (CCM)** surveille les services K8s de type
`LoadBalancer` et provisionne automatiquement des Load Balancers Scaleway managés.

Il remplace MetalLB (`proxmox/`) et le CCM OVH (`cloud/`).

## Fonctionnement

```
Service K8s type: LoadBalancer
  → scaleway-cloud-controller-manager détecte le service
    → API Scaleway → création Load Balancer managé
      → IP publique assignée au service (status.loadBalancer.ingress)
```

## Usage concret

Ingress-nginx reçoit automatiquement une IP publique Scaleway :

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# ingress-nginx-controller   LoadBalancer   10.96.x.x      <IP_SCALEWAY_LB> 80:xxx,443:xxx
```

Cette IP est celle à pointer dans le DNS pour les domaines `*.k8s.yplank.fr`.

## Différence vs OVH (cloud/)

| Aspect | OVH CCM (cloud/) | Scaleway CCM (cloud2/) |
|--------|-----------------|----------------------|
| Config | Fichier `cloud.conf` (ini OpenStack) | Secret K8s avec API keys Scaleway |
| Terraform | Floating IP LB pré-provisionnée | LB créé dynamiquement par le CCM |
| Facturation | LB OVH facturé à la création | LB Scaleway facturé à l'usage |

## Vérification

```bash
kubectl get pods -n kube-system | grep scaleway-cloud-controller
kubectl logs -n kube-system -l app=scaleway-cloud-controller-manager --tail=20
```
