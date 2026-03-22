# Terraform — Scaleway

## Structure des fichiers

| Fichier | Rôle |
|---------|------|
| `backend.tf` | Remote state S3 Scaleway Object Storage |
| `provider.tf` | Provider `scaleway/scaleway` |
| `network.tf` | VPC Private Network inter-nodes |
| `main.tf` | Instances + IPs flexibles |
| `variables.tf` | Paramètres configurables |
| `outputs.tf` | IPs exportées pour l'inventaire Ansible |

## Remote state S3

Le state Terraform est stocké sur Scaleway Object Storage (compatible S3).

Le bucket doit être créé **manuellement une seule fois** avant le premier `terraform init`.
Voir [scaleway-setup.md](scaleway-setup.md) §4.

Variables d'environnement nécessaires :
```bash
export AWS_ACCESS_KEY_ID="<TF_BACKEND_ACCESS_KEY>"
export AWS_SECRET_ACCESS_KEY="<TF_BACKEND_SECRET_KEY>"
```

## Variables principales

| Variable | Défaut | Description |
|----------|--------|-------------|
| `scw_region` | `fr-par` | Région Scaleway |
| `scw_zone` | `fr-par-2` | Zone Scaleway |
| `instance_type_cp` | `DEV1-L` | Type control plane (4 vCPU / 8 Go) |
| `instance_type_worker` | `DEV1-XL` | Type workers (4 vCPU / 12 Go) |
| `image` | `almalinux_9` | Image OS — vérifier avec `scw marketplace image list` |
| `cluster_name` | `rncp-scw` | Préfixe des noms de ressources |
| `domain` | `k8s.yplank.fr` | Domaine pour les services exposés |

Pour surcharger localement, créer `terraform/terraform.tfvars` (gitignored) :
```hcl
scw_zone             = "fr-par-1"
instance_type_worker = "GP1-S"
```

## Ressources créées

- 3 instances Scaleway (`scw-cp-01`, `scw-worker-01`, `scw-worker-02`)
- 3 IPs flexibles publiques (une par instance)
- 1 VPC Private Network pour la communication inter-nodes

## Différences clés vs OVH

| Aspect | OVH (cloud/) | Scaleway (cloud2/) |
|--------|-------------|-------------------|
| Réseau privé | vRack + port_security_enabled=false requis | VPC Private Network — pas d'anti-spoofing |
| IPs publiques | Floating IPs + router NAT | IPs flexibles attachées directement |
| Load Balancer | Ressource Terraform séparée | Provisionné automatiquement par le CCM |
| SSH Key | Référencée par nom (`var.ssh_key_name`) | Injectée automatiquement depuis le projet |

> **Pourquoi pas de `port_security_enabled` ?**
> Scaleway n'utilise pas le modèle OpenStack Neutron. Les VPC Private Networks
> n'ont pas d'anti-spoofing — Cilium et le trafic inter-pods fonctionnent nativement.
