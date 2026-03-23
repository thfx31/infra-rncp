# ── Réseau privé inter-nodes ──────────────────────────────
# Scaleway VPC Private Network — pas de port_security, pas d'anti-spoofing
# Compatible Kubernetes/Cilium sans configuration spéciale
resource "scaleway_vpc_private_network" "cluster" {
  name   = "${var.cluster_name}-private"
  region = var.scw_region

  tags = ["project:rncp", "managed-by:terraform"]
}
