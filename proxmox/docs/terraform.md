# Terraform — Provisionnement Proxmox (provider bpg/proxmox)

## Prérequis

1. **Terraform** >= 1.5 installé
2. **Token API Proxmox** créé (voir `guide-prerequis-proxmox.md`)
3. **Template cloud-init** AlmaLinux 9 (ID 9000) créé sur Proxmox

## Architecture

Le Terraform provisionne uniquement les **nodes du cluster Kubernetes**.
La machine d'administration (bastion) est gérée indépendamment — elle est le point d'entrée pour piloter l'infra et ne doit pas dépendre du code qu'elle exécute.

## Configuration

### Variables d'environnement (obligatoire)

```bash
source ~/.proxmox-terraform.env
```

Ce fichier doit contenir :
```bash
export PROXMOX_VE_ENDPOINT="https://<PROXMOX_IP>:8006/"
export PROXMOX_VE_API_TOKEN="terraform@pam!terraform-token=<TOKEN_SECRET>"
```

> **Format du token** : `TOKEN_ID=TOKEN_SECRET` en une seule variable.

### Permissions Proxmox

L'utilisateur `terraform@pam` doit avoir un rôle avec les privilèges suivants :

```bash
pveum roleadd TerraformRole -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit SDN.Audit SDN.Use Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Console VM.Migrate VM.PowerMgmt VM.Snapshot VM.Snapshot.Rollback VM.GuestAgent.Audit VM.GuestAgent.Unrestricted"

pveum aclmod / -user terraform@pam -role TerraformRole
```

## Utilisation

```bash
# Charger les credentials
source ~/.proxmox-terraform.env

cd terraform/proxmox/

# Initialiser les providers
terraform init

# Prévisualiser les changements
terraform plan

# Appliquer (créer les VM)
terraform apply -parallelism=1

# Détruire (supprimer les VM)
terraform destroy
```

> **Note** : `-parallelism=1` évite les erreurs de lock lors du clone simultané de plusieurs VM depuis le même template.

## VM créées par Terraform

| Nom | VMID | IP | vCPU | RAM | Disque | Rôle |
|-----|------|----|------|-----|--------|------|
| rncp-cp-01 | 120 | 192.168.1.120 | 2 | 4 Go | 50 Go | K8s Control Plane |
| rncp-worker-01 | 121 | 192.168.1.121 | 2 | 8 Go | 80 Go | K8s Worker |
| rncp-worker-02 | 122 | 192.168.1.122 | 2 | 8 Go | 80 Go | K8s Worker |

### Machine d'administration (hors Terraform)

| Nom | IP | vCPU | RAM | Disque | Rôle |
|-----|-----|------|-----|--------|------|
| rncp-bastion | 192.168.1.130 | 2 | 2 Go | 30 Go | Terraform, Ansible, kubectl, Helm |


## Connexion SSH

```bash
ssh admintf@192.168.1.120  # rncp-cp-01
ssh admintf@192.168.1.121  # rncp-worker-01
ssh admintf@192.168.1.122  # rncp-worker-02
ssh admintf@192.168.1.130  # rncp-bastion
```

## Structure des fichiers

| Fichier | Rôle |
|---------|------|
| `provider.tf` | Configuration du provider bpg/proxmox |
| `variables.tf` | Définition de toutes les variables |
| `main.tf` | Ressources — création des VM par clone du template |
| `outputs.tf` | Affichage des IP et commandes SSH |
| `terraform.tfvars` | Valeurs spécifiques à l'environnement |