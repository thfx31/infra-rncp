# =============================================================================
# Main — Provisionnement des VM du POC Kubernetes
# =============================================================================

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vms

  # --- Identité ---
  name      = each.key
  vm_id     = each.value.vmid
  node_name = var.proxmox_node

  description = "POC K8s - ${each.key} | Géré par Terraform"
  tags        = ["AlmaLinux9","rncp-k8s", "terraform"]

  # --- Clone depuis le template cloud-init ---
  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  # --- Empêcher le démarrage automatique pendant le provisionnement ---
  started        = true
  stop_on_destroy = true

  # --- Ressources CPU ---
  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  # --- Ressources RAM ---
  memory {
    dedicated = each.value.memory
  }

  # --- Agent QEMU (nécessaire pour récupérer l'IP) ---
  agent {
    enabled = true
  }

  # --- Disque principal ---
  # On redimensionne le disque hérité du template
  disk {
    interface    = "scsi0"
    size         = each.value.disk_gb
    datastore_id = var.storage
  }

  # --- Réseau ---
  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  # --- Cloud-init ---
  initialization {
    datastore_id = var.storage

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_server]
    }

    user_account {
      username = var.ci_user
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_file)))]
    }
  }

  # --- Lifecycle ---
  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}
