# ── Réseau privé vRack ───────────────────────────────────
resource "openstack_networking_network_v2" "private" {
  name           = "${var.cluster_name}-private"
  admin_state_up = true

  tags = ["project:rncp", "managed-by:terraform"]
}

resource "openstack_networking_subnet_v2" "private" {
  name            = "${var.cluster_name}-subnet"
  network_id      = openstack_networking_network_v2.private.id
  cidr            = var.vrack_subnet
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = ["213.186.33.99"]  # DNS OVH

  tags = ["project:rncp", "managed-by:terraform"]
}

# ── Router pour accès internet depuis le vRack ───────────
data "openstack_networking_network_v2" "ext_net" {
  name = "Ext-Net"
}

resource "openstack_networking_router_v2" "router" {
  name                = "${var.cluster_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net.id

  tags = ["project:rncp", "managed-by:terraform"]
}

resource "openstack_networking_router_interface_v2" "router_iface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.private.id

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# ── Security groups supprimés (quota OVH = 0 sur ce projet) ──
# La sécurité réseau est assurée par firewalld + SELinux via Ansible.
# Les instances utilisent uniquement le groupe "default" (existant).
