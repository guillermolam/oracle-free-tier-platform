# UpCloud infrastructure module
# Consolidates networks, routers, servers, storage, and firewall resources

locals {
  # The default SSH rule remains configurable without changing the public
  # firewall_rules object contract. When bootstrap_cidr is set, constrain the
  # rule to that CIDR's first and last addresses.
  effective_inbound_rules = [
    for rule in var.firewall_rules.inbound : merge(
      rule,
      rule.protocol == "tcp" && rule.destination_port_start == 22 ? {
        destination_port_start = var.ssh_port
        destination_port_end   = var.ssh_port
        source_address_start   = var.bootstrap_cidr == "" ? null : cidrhost(var.bootstrap_cidr, 0)
        source_address_end     = var.bootstrap_cidr == "" ? null : cidrhost(var.bootstrap_cidr, -1)
      } : {}
    )
  ]
}

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

  # UpCloud provider 5.x models tags as a set of strings. Preserve the
  # module's map(string) interface and serialize entries as key=value tags.
  tags = toset([for key, value in var.tags : "${key}=${value}"])

  dynamic "login" {
    for_each = var.admin_ssh_key == "" ? [] : [var.admin_ssh_key]
    content {
      user = var.admin_user
      keys = [login.value]
    }
  }

  user_data = var.user_data == "" ? null : var.user_data

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
    for_each = local.effective_inbound_rules
    content {
      action    = "accept"
      direction = "in"
      family    = firewall_rule.value.family

      protocol = firewall_rule.value.protocol

      destination_port_start = firewall_rule.value.protocol == "icmp" ? "" : tostring(firewall_rule.value.destination_port_start)
      destination_port_end   = firewall_rule.value.protocol == "icmp" ? "" : tostring(firewall_rule.value.destination_port_end)

      source_port_start = firewall_rule.value.protocol == "icmp" || firewall_rule.value.source_port_start == null ? "" : tostring(firewall_rule.value.source_port_start)
      source_port_end   = firewall_rule.value.protocol == "icmp" || firewall_rule.value.source_port_end == null ? "" : tostring(firewall_rule.value.source_port_end)

      source_address_start = try(firewall_rule.value.source_address_start, null)
      source_address_end   = try(firewall_rule.value.source_address_end, null)

      icmp_type = firewall_rule.value.icmp_type == null ? "" : tostring(firewall_rule.value.icmp_type)
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

      destination_port_start = firewall_rule.value.protocol == "icmp" ? "" : tostring(firewall_rule.value.destination_port_start)
      destination_port_end   = firewall_rule.value.protocol == "icmp" ? "" : tostring(firewall_rule.value.destination_port_end)

      source_port_start = firewall_rule.value.protocol == "icmp" || firewall_rule.value.source_port_start == null ? "" : tostring(firewall_rule.value.source_port_start)
      source_port_end   = firewall_rule.value.protocol == "icmp" || firewall_rule.value.source_port_end == null ? "" : tostring(firewall_rule.value.source_port_end)

      source_address_start = try(firewall_rule.value.source_address_start, null)
      source_address_end   = try(firewall_rule.value.source_address_end, null)

      icmp_type = firewall_rule.value.icmp_type == null ? "" : tostring(firewall_rule.value.icmp_type)
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
