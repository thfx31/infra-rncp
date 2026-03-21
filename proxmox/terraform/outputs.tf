# =============================================================================
# Outputs — Récapitulatif des VM créées
# =============================================================================

output "vm_summary" {
  description = "Tableau récapitulatif des VM et leurs IP"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm :
    name => {
      vmid = vm.vm_id
      ip   = var.vms[name].ip
    }
  }
}

output "ssh_commands" {
  description = "Commandes SSH pour se connecter aux VM"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm :
    name => "ssh ${var.ci_user}@${var.vms[name].ip}"
  }
}
