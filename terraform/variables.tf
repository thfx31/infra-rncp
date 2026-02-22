# =============================================================================
# Variables — Infrastructure POC Kubernetes
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox
# -----------------------------------------------------------------------------
variable "proxmox_node" {
  description = "Nom du nœud Proxmox"
  type        = string
  default     = "pve02"
}

variable "template_vm_id" {
  description = "ID de la VM template cloud-init à cloner"
  type        = number
  default     = 9000
}

variable "storage" {
  description = "Nom du stockage Proxmox pour les disques VM"
  type        = string
  default     = "local-lvm"
}

# -----------------------------------------------------------------------------
# Réseau
# -----------------------------------------------------------------------------
variable "gateway" {
  description = "Passerelle réseau"
  type        = string
  default     = "192.168.1.254"
}

variable "dns_server" {
  description = "Serveur DNS"
  type        = string
  default     = "192.168.1.250"
}

variable "bridge" {
  description = "Bridge réseau Proxmox"
  type        = string
  default     = "vmbr0"
}

# -----------------------------------------------------------------------------
# Cloud-init
# -----------------------------------------------------------------------------
variable "ci_user" {
  description = "Utilisateur créé par cloud-init sur les VM"
  type        = string
  default     = "admintf"
}

variable "ssh_public_key_files" {
  description = "Chemin vers la clé SSH publique à injecter dans les VM"
  type        = list(string)
  default     = [
    "~/.ssh/id_bastion.pub", # Clé pour l'accès depuis la machine bastion
    "~/.ssh/perso_key.pub", # Clé pour l'accès depuis la machine personnelle
  ]
}

# -----------------------------------------------------------------------------
# Définition des VM
# -----------------------------------------------------------------------------
variable "vms" {
  description = "Map des VM à créer"
  type = map(object({
    vmid    = number
    cores   = number
    memory  = number # en Mo
    disk_gb = number # en Go
    ip      = string
  }))

  default = {
    cp-01 = {
      vmid    = 120
      cores   = 2
      memory  = 4096
      disk_gb = 50
      ip      = "192.168.1.120"
    }
    worker-01 = {
      vmid    = 121
      cores   = 2
      memory  = 8192
      disk_gb = 80
      ip      = "192.168.1.121"
    }
    worker-02 = {
      vmid    = 122
      cores   = 2
      memory  = 8192
      disk_gb = 80
      ip      = "192.168.1.122"
    }
  }
}
