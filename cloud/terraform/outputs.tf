# Outputs utilisés par ansible/inventory.py pour générer l'inventaire dynamique

output "control_plane_ip_public" {
  description = "IP publique du control plane (SSH Ansible)"
  value       = openstack_networking_floatingip_v2.nodes["cp"].address
}

output "control_plane_ip_private" {
  description = "IP vRack du control plane (communication K8s)"
  value       = openstack_compute_instance_v2.nodes["cp"].network[0].fixed_ip_v4
}

output "worker01_ip_public" {
  description = "IP publique worker-01"
  value       = openstack_networking_floatingip_v2.nodes["worker01"].address
}

output "worker01_ip_private" {
  description = "IP vRack worker-01"
  value       = openstack_compute_instance_v2.nodes["worker01"].network[0].fixed_ip_v4
}

output "worker02_ip_public" {
  description = "IP publique worker-02"
  value       = openstack_networking_floatingip_v2.nodes["worker02"].address
}

output "worker02_ip_private" {
  description = "IP vRack worker-02"
  value       = openstack_compute_instance_v2.nodes["worker02"].network[0].fixed_ip_v4
}

output "lb_ip" {
  description = "IP publique du Load Balancer ingress"
  value       = openstack_networking_floatingip_v2.lb.address
}

output "cluster_summary" {
  description = "Résumé des IPs du cluster"
  value = {
    cp       = openstack_networking_floatingip_v2.nodes["cp"].address
    worker01 = openstack_networking_floatingip_v2.nodes["worker01"].address
    worker02 = openstack_networking_floatingip_v2.nodes["worker02"].address
    lb       = openstack_networking_floatingip_v2.lb.address
  }
}
