# Préparer Proxmox pour Terraform

## Prérequis
- Proxmox VE installé et accessible via l'interface web
- Accès SSH root au serveur Proxmox
- Connexion internet sur le serveur Proxmox (pour télécharger l'image AlmaLinux)

---

## Partie 1 — Créer un token API Proxmox pour Terraform

Terraform a besoin d'un accès API à Proxmox pour créer/modifier/supprimer des VM.
On va créer un utilisateur dédié avec un token API.

### Étape 1.1 — Créer un utilisateur dédié

Sur le serveur Proxmox (via SSH) :

```bash
# Créer un utilisateur "terraform" dans le realm PAM
pveum useradd terraform@pam --comment "Utilisateur pour Terraform"
```

### Étape 1.2 — Créer un rôle avec les bons droits

```bash
# Créer un rôle dédié avec les permissions nécessaires
pveum roleadd TerraformRole -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit SDN.Audit SDN.Use Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Console VM.Migrate VM.PowerMgmt VM.Snapshot VM.Snapshot.Rollback"
```

### Étape 1.3 — Attribuer le rôle à l'utilisateur

```bash
# Donner les droits sur tout le datacenter
pveum aclmod / -user terraform@pam -role TerraformRole
```

### Étape 1.4 — Créer le token API

```bash
# Créer un token nommé "terraform-token"
# IMPORTANT : --privsep 0 pour que le token hérite des droits de l'utilisateur
pveum user token add terraform@pam terraform-token --privsep 0
```

**⚠️ IMPORTANT** : Cette commande affiche le token UNE SEULE FOIS. 

Le résultat ressemble à :
```
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ terraform@pam!terraform-token        │
│ info         │ {"privsep":"0"}                      │
│ value        │ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx │
└──────────────┴──────────────────────────────────────┘
```

### Étape 1.5 — Vérifier que ça fonctionne

```bash
# Tester l'accès API depuis le serveur lui-même
curl -s -k \
  -H 'Authorization: PVEAPIToken=terraform@pam!terraform-token=<TOKEN_VALUE>' \
  https://<PROXMOX_IP>:8006/api2/json/nodes | jq .
```

Le node Poxmox doit s'afficher avec la réponse JSON : `"status": "online"`

### Étape 1.6 — Stocker le token en sécurité

Crée un fichier sur la machine d'admin (futur bastion) :

```bash
# Fichier d'environnement pour Terraform (NE PAS commit sur Git !)
cat > ~/.proxmox-terraform.env << 'EOF'
export PROXMOX_VE_ENDPOINT="https://192.168.1.x:8006/"
export PROXMOX_VE_API_TOKEN="terraform@pam!terraform-token=TON_SECRET_ICI"
EOF

chmod 600 ~/.proxmox-terraform.env
```

Pour charger les variables avant d'utiliser Terraform :
```bash
source ~/.proxmox-terraform.env
```

---

## Partie 2 — Créer le template cloud-init AlmaLinux 9

Cloud-init permet à Terraform de personnaliser les VM au démarrage (hostname, IP, clé SSH, packages...).
On va créer un template de VM avec cloud-init, que Terraform clonera ensuite pour chaque VM.

### Étape 2.1 — Télécharger l'image cloud AlmaLinux 9

Sur le serveur Proxmox (via SSH) :

```bash
# Se placer dans le répertoire des images ISO/templates
cd /var/lib/vz/template/

# Télécharger l'image cloud (format qcow2, prête pour cloud-init)
wget https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
```

### Étape 2.2 — Créer la VM qui servira de template

```bash
# Créer une VM avec l'ID 9000 (convention : 9xxx pour les templates)
qm create 9000 --name almalinux9-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Importer le disque qcow2 dans le stockage local-lvm
# (adapte "local-lvm" si ton stockage s'appelle autrement)
qm importdisk 9000 /var/lib/vz/template/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2 local-lvm
# ⚠️ Note le nom du disque dans la sortie (ex: "vm-9000-disk-0" ou "vm-9000-disk-1")

# Attacher le disque importé à la VM
# ⚠️ Adapte le nom du disque selon la sortie de la commande précédente
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Configurer le boot sur le disque
qm set 9000 --boot order=scsi0

# Ajouter le lecteur cloud-init (obligatoire !)
qm set 9000 --ide2 local-lvm:cloudinit

# Activer le serial console (nécessaire pour cloud-init sur certaines images)
qm set 9000 --serial0 socket --vga serial0

# Activer l'agent QEMU (utile pour récupérer l'IP dans Terraform)
qm set 9000 --agent enabled=1
```

### Étape 2.3 — Configurer les valeurs par défaut cloud-init

```bash
# Utilisateur par défaut
qm set 9000 --ciuser admintf
```

**Clé SSH** : on injecte la clé publique de ta **machine perso** (celle depuis laquelle tu te connectes en SSH). C'est elle qui pourra se connecter aux VM créées par Terraform.

Depuis **ta machine perso** :
```bash
# Copier ta clé publique vers Proxmox
scp ~/.ssh/id_ed25519.pub root@<PROXMOX_IP>:/tmp/my_key.pub
```

> 💡 Si ta clé est de type RSA, remplace `id_ed25519.pub` par `id_rsa.pub`.
> Si tu n'as pas encore de clé SSH, génère-en une : `ssh-keygen -t ed25519`

Puis sur **Proxmox** :
```bash
# Injecter la clé dans le template
qm set 9000 --sshkeys /tmp/my_key.pub

# Nettoyer
rm /tmp/my_key.pub

# Configuration IP par DHCP (Terraform surchargera avec des IP statiques)
qm set 9000 --ipconfig0 ip=dhcp
```

### Étape 2.4 — Convertir en template

```bash
# Convertir la VM en template (irréversible !)
qm template 9000
```
