# ── OVH Load Balancer (Octavia) ───────────────────────────
# Le LB est géré dynamiquement par l'openstack cloud-controller-manager
# déployé via le rôle Ansible ovh-lb/.
#
# Ce fichier configure une IP flottante dédiée au LB qui sera attribuée
# au service ingress-nginx par le CCM.

resource "openstack_networking_floatingip_v2" "lb" {
  pool        = "Ext-Net"
  description = "${var.cluster_name} ingress LB"
}

output "lb_floating_ip" {
  description = "IP publique réservée pour le Load Balancer ingress"
  value       = openstack_networking_floatingip_v2.lb.address
}
