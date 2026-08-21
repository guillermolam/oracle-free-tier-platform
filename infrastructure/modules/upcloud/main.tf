# UpCloud infrastructure module
# Consolidates networks, routers, servers, storage, and firewall resources

# Network and router: one network with embedded router
resource "upcloud_router" "node_router" {
  name = var.router_name
}

resource "upcloud_network" "node_network" {
  name   = var.network_name
  zone   = var.zone
  router = upcloud_router.node_router.id

  ip_network {
    address            = var.network_cidr
    dhcp               = true
    dhcp_default_route = true
    family             = "IPv4"
    gateway            = "10.0.0.1"
  }

  depends_on = [
    terraform_data.zone_validation
  ]
}

# Storage: root disk
resource "upcloud_storage" "root_disk" {
  size  = var.disk_size
  tier  = var.storage_tier
  title = "${var.hostname}-os"
  zone  = var.zone

  depends_on = [
    terraform_data.zone_validation
  ]
}

# Server: single node
resource "upcloud_server" "node" {
  firewall = true
  hostname = var.hostname
  metadata = var.metadata_enabled
  title    = var.hostname
  zone     = var.zone
  plan     = var.plan

  network_interface {
    ip_address_family = "IPv4"
    type              = "public"
  }

  network_interface {
    type              = "private"
    network           = upcloud_network.node_network.id
    ip_address_family = "IPv4"
  }

  storage_devices {
    address = "virtio"
    storage = upcloud_storage.root_disk.id
    type    = "disk"
  }

  tags = var.tags

  depends_on = [
    upcloud_network.node_network,
    upcloud_storage.root_disk,
    terraform_data.debian_image_validation,
  ]

  lifecycle {
    ignore_changes = [storage_devices]
  }
}

# Firewall rules: inbound and outbound
resource "upcloud_firewall_rules" "node_firewall" {
  server_id = upcloud_server.node.id

  # Inbound rules
  dynamic "firewall_rule" {
    for_each = var.firewall_rules.inbound
    content {
      action    = "accept"
      direction = "in"
      family    = firewall_rule.value.family

      protocol = firewall_rule.value.protocol

      destination_port_start = firewall_rule.value.destination_port_start
      destination_port_end   = firewall_rule.value.destination_port_end

      source_port_start = firewall_rule.value.source_port_start
      source_port_end   = firewall_rule.value.source_port_end

      icmp_type = firewall_rule.value.icmp_type
    }
  }

  # Outbound rules
  dynamic "firewall_rule" {
    for_each = var.firewall_rules.outbound
    content {
      action    = "accept"
      direction = "out"
      family    = firewall_rule.value.family

      protocol = firewall_rule.value.protocol

      destination_port_start = firewall_rule.value.destination_port_start
      destination_port_end   = firewall_rule.value.destination_port_end

      source_port_start = firewall_rule.value.source_port_start
      source_port_end   = firewall_rule.value.source_port_end

      icmp_type = firewall_rule.value.icmp_type
    }
  }

  # Default deny rules
  firewall_rule {
    action    = "drop"
    direction = "in"
  }

  firewall_rule {
    action    = "drop"
    direction = "out"
  }

  depends_on = [upcloud_server.node]
}
