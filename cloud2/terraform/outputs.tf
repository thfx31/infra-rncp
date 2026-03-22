# Outputs utilisés par ansible/inventory.py

output "control_plane_ip_public" {
  description = "IP publique du control plane"
  value       = scaleway_instance_ip.nodes["cp"].address
}

output "control_plane_ip_private" {
  description = "IP privée du control plane (réseau inter-nodes)"
  value       = scaleway_instance_server.nodes["cp"].private_network[0].ip
}

output "worker01_ip_public" {
  description = "IP publique worker-01"
  value       = scaleway_instance_ip.nodes["worker01"].address
}

output "worker01_ip_private" {
  description = "IP privée worker-01"
  value       = scaleway_instance_server.nodes["worker01"].private_network[0].ip
}

output "worker02_ip_public" {
  description = "IP publique worker-02"
  value       = scaleway_instance_ip.nodes["worker02"].address
}

output "worker02_ip_private" {
  description = "IP privée worker-02"
  value       = scaleway_instance_server.nodes["worker02"].private_network[0].ip
}

output "cluster_summary" {
  description = "Résumé des IPs du cluster"
  value = {
    cp       = scaleway_instance_ip.nodes["cp"].address
    worker01 = scaleway_instance_ip.nodes["worker01"].address
    worker02 = scaleway_instance_ip.nodes["worker02"].address
  }
}
