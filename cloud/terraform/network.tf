# ── Réseau privé vRack ───────────────────────────────────
resource "openstack_networking_network_v2" "private" {
  name           = "${var.cluster_name}-private"
  admin_state_up = true

  tags = ["project:rncp", "managed-by:terraform"]
}

resource "openstack_networking_subnet_v2" "private" {
  name        = "${var.cluster_name}-subnet"
  network_id  = openstack_networking_network_v2.private.id
  cidr        = var.vrack_subnet
  ip_version  = 4
  enable_dhcp = true
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
}

# ── Security group commun (SSH + ICMP + trafic interne) ──
resource "openstack_networking_secgroup_v2" "common" {
  name        = "${var.cluster_name}-common"
  description = "SSH, ICMP et trafic interne vRack"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.common.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.common.id
}

resource "openstack_networking_secgroup_rule_v2" "internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = var.vrack_subnet
  security_group_id = openstack_networking_secgroup_v2.common.id
}

# ── Security group control plane ─────────────────────────
resource "openstack_networking_secgroup_v2" "control_plane" {
  name        = "${var.cluster_name}-control-plane"
  description = "Ports API K8s et etcd"
}

resource "openstack_networking_secgroup_rule_v2" "api_server" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "etcd" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2379
  port_range_max    = 2380
  remote_ip_prefix  = var.vrack_subnet
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

# ── Security group workers ────────────────────────────────
resource "openstack_networking_secgroup_v2" "workers" {
  name        = "${var.cluster_name}-workers"
  description = "HTTP/HTTPS publics + NodePort"
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "nodeport" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.workers.id
}
