# Terraform — OVH Public Cloud

## Structure des fichiers

| Fichier | Rôle |
|---------|------|
| `backend.tf` | Remote state S3 OVH Object Storage |
| `provider.tf` | Providers ovh/ovh et openstack |
| `network.tf` | vRack, subnet privé, security groups |
| `lb.tf` | OVH Load Balancer managé |
| `main.tf` | Instances OVH |
| `variables.tf` | Paramètres configurables |
| `outputs.tf` | IPs exportées pour l'inventaire Ansible |

## Remote state S3

Le state Terraform est stocké sur OVH Object Storage (compatible S3) pour permettre
son partage entre la machine locale et GitHub Actions.

Le bucket doit être créé **manuellement une seule fois** avant le premier `terraform init`.
Voir [ovh-setup.md](ovh-setup.md) §5.

Variables d'environnement nécessaires pour `terraform init` :
```bash
export TF_BACKEND_ACCESS_KEY="..."
export TF_BACKEND_SECRET_KEY="..."
```

## Variables principales

| Variable | Exemple | Description |
|----------|---------|-------------|
| `region` | `GRA11` | Région OVH |
| `flavor_cp` | `b3-8` | Flavor control plane (4 vCPUs / 8 Go) |
| `flavor_worker` | `b3-16` | Flavor workers (8 vCPUs / 16 Go) |
| `ssh_key_name` | `rncp-ovh` | Nom clé SSH dans OVH |
| `cluster_name` | `rncp-ovh` | Préfixe des noms de ressources |
| `domain` | `k8s.thfx.fr` | Domaine pour les services exposés |
| `vrack_subnet` | `10.0.0.0/24` | Plage réseau privé vRack |

Pour les surcharger localement, créer un fichier `terraform/terraform.tfvars`
(gitignored) :
```hcl
region       = "GRA11"
cluster_name = "rncp-ovh"
```

## Commandes

```bash
make tf-init     # initialiser Terraform + backend S3
make tf-plan     # voir les ressources à créer/modifier
make tf-apply    # appliquer
make tf-output   # afficher les outputs JSON (IPs des instances)
make tf-destroy  # tout supprimer
```

## Tags OVH (obligatoires)

Chaque ressource doit avoir les tags suivants pour le suivi des coûts :
```hcl
metadata = {
  project     = "rncp39582"
  environment = "poc"
  managed-by  = "terraform"
}
```

## Ressources créées

- 3 instances OVH (ovh-cp-01, ovh-worker-01, ovh-worker-02)
- 1 réseau privé vRack + 1 subnet
- 3 security groups (control-plane, workers, common)
- 1 OVH Load Balancer managé
- Floating IPs publiques pour chaque instance
