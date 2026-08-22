run "valid_minimal_configuration" {
  command = plan

  variables {
    zone             = "es-mad1"
    plan             = "DEV-2xCPU-4GB"
    disk_size        = 60
    hostname         = "k8s-node"
    admin_user       = "ubuntu"
    admin_ssh_key    = "ssh-ed25519 AAAA..."
    bootstrap_cidr   = "203.0.113.0/24"
    ssh_port         = 22
    network_name     = "k8s-network"
    network_cidr     = "10.0.0.0/24"
    router_name      = "k8s-router"
    storage_tier     = "standard"
    metadata_enabled = true
  }

  assert {
    condition     = upcloud_server.node != null
    error_message = "Server resource should be created"
  }

  assert {
    condition     = upcloud_network.node_network != null
    error_message = "Network resource should be created"
  }

  assert {
    condition     = upcloud_router.node_router != null
    error_message = "Router resource should be created"
  }

  assert {
    condition     = upcloud_storage.root_disk != null
    error_message = "Storage resource should be created"
  }

  assert {
    condition     = upcloud_firewall_rules.node_firewall != null
    error_message = "Firewall rules resource should be created"
  }
}

run "valid_custom_hostname" {
  command = plan

  variables {
    zone     = "es-mad1"
    hostname = "k8s-worker-01"
  }

  assert {
    condition     = upcloud_server.node.hostname == "k8s-worker-01"
    error_message = "Server hostname should match variable"
  }
}

run "valid_disk_size_range" {
  command = plan

  variables {
    disk_size = 100
  }

  assert {
    condition     = upcloud_storage.root_disk.size == 100
    error_message = "Storage size should match variable"
  }
}

run "valid_firewall_rules_present" {
  command = plan

  variables {
    zone = "es-mad1"
  }

  assert {
    condition     = length(upcloud_firewall_rules.node_firewall.firewall_rule) > 0
    error_message = "Firewall rules should be defined"
  }

  assert {
    condition     = can([for r in upcloud_firewall_rules.node_firewall.firewall_rule : r.action if r.action == "drop"])
    error_message = "Default deny rules should be present"
  }
}

run "valid_default_firewall_rules" {
  command = plan

  assert {
    condition     = contains([for r in upcloud_firewall_rules.node_firewall.firewall_rule : r.protocol if r.direction == "in"], "tcp")
    error_message = "Default inbound TCP rule should be present"
  }

  assert {
    condition     = contains([for r in upcloud_firewall_rules.node_firewall.firewall_rule : r.protocol if r.direction == "out"], "udp")
    error_message = "Default outbound UDP rule should be present"
  }
}

run "valid_custom_tags" {
  command = plan

  variables {
    tags = {
      environment = "production"
      owner       = "ops-team"
      cluster     = "main"
    }
  }

  assert {
    condition     = upcloud_server.node.tags["environment"] == "production"
    error_message = "Custom tags should be applied to server"
  }
}

run "valid_zone_validation" {
  command = plan

  variables {
    zone = "es-mad1"
  }

  assert {
    condition     = upcloud_server.node.zone == "es-mad1"
    error_message = "Server zone should match variable"
  }
}

run "valid_network_configuration" {
  command = plan

  variables {
    network_cidr = "10.1.0.0/24"
    network_name = "custom-network"
  }

  assert {
    condition     = upcloud_network.node_network.name == "custom-network"
    error_message = "Network name should match variable"
  }

  assert {
    condition     = upcloud_network.node_network.ip_network[0].address == "10.1.0.0/24"
    error_message = "Network CIDR should match variable"
  }
}

run "valid_storage_tier_standard" {
  command = plan

  variables {
    storage_tier = "standard"
  }

  assert {
    condition     = upcloud_storage.root_disk.tier == "standard"
    error_message = "Storage tier should be 'standard'"
  }
}

run "valid_metadata_enabled" {
  command = plan

  variables {
    metadata_enabled = true
  }

  assert {
    condition     = upcloud_server.node.metadata == true
    error_message = "Metadata service should be enabled"
  }
}

run "valid_metadata_disabled" {
  command = plan

  variables {
    metadata_enabled = false
  }

  assert {
    condition     = upcloud_server.node.metadata == false
    error_message = "Metadata service should be disabled"
  }
}
