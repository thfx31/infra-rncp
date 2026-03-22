locals {
  nodes = {
    cp = {
      name       = "${var.cluster_name}-cp-01"
      flavor     = var.flavor_cp
      private_ip = cidrhost(var.vrack_subnet, 10)  # 10.0.0.10
    }
    worker01 = {
      name       = "${var.cluster_name}-worker-01"
      flavor     = var.flavor_worker
      private_ip = cidrhost(var.vrack_subnet, 11)  # 10.0.0.11
    }
    worker02 = {
      name       = "${var.cluster_name}-worker-02"
      flavor     = var.flavor_worker
      private_ip = cidrhost(var.vrack_subnet, 12)  # 10.0.0.12
    }
  }
}

data "openstack_images_image_v2" "almalinux" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_keypair_v2" "ssh_key" {
  name = var.ssh_key_name
}

# ── Ports réseau explicites (nécessaires pour l'association des floating IPs) ──
resource "openstack_networking_port_v2" "nodes" {
  for_each   = local.nodes

  name                  = "${each.value.name}-port"
  network_id            = openstack_networking_network_v2.private.id
  admin_state_up        = true
  port_security_enabled = false

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.private.id
    ip_address = each.value.private_ip
  }
}

# ── Instances ─────────────────────────────────────────────
resource "openstack_compute_instance_v2" "nodes" {
  for_each = local.nodes

  name        = each.value.name
  image_id    = data.openstack_images_image_v2.almalinux.id
  flavor_name = each.value.flavor
  key_pair    = data.openstack_compute_keypair_v2.ssh_key.name

  metadata = {
    project     = "rncp39582"
    environment = "poc"
    managed-by  = "terraform"
    role        = each.key
  }

  network {
    port = openstack_networking_port_v2.nodes[each.key].id
  }
}

# ── IPs publiques flottantes ──────────────────────────────
resource "openstack_networking_floatingip_v2" "nodes" {
  for_each = local.nodes
  pool     = "Ext-Net"
}

resource "openstack_networking_floatingip_associate_v2" "nodes" {
  for_each    = local.nodes
  floating_ip = openstack_networking_floatingip_v2.nodes[each.key].address
  port_id     = openstack_networking_port_v2.nodes[each.key].id

  depends_on = [openstack_networking_router_interface_v2.router_iface]
}
