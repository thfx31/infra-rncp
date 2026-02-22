# =============================================================================
# terraform.tfvars — Valeurs spécifiques à ton environnement
# =============================================================================

proxmox_node = "pve02"
storage      = "local-lvm"
bridge       = "vmbr0"
gateway      = "192.168.1.254"
dns_server   = "192.168.1.250"
ci_user      = "admintf"
