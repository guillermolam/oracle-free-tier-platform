output "server_id" {
  value       = upcloud_server.node.id
  description = "UpCloud server ID"
}

output "server_ip_address" {
  value       = upcloud_server.node.network_interface[0].ip_address
  description = "Server primary IP address"
}

output "server_hostname" {
  value       = upcloud_server.node.hostname
  description = "Server hostname"
}

output "server_zone" {
  value       = upcloud_server.node.zone
  description = "Server availability zone"
}

output "network_id" {
  value       = upcloud_network.node_network.id
  description = "UpCloud network ID"
}

output "network_address" {
  value       = upcloud_network.node_network.ip_network[0].address
  description = "Network CIDR block"
}

output "router_id" {
  value       = upcloud_router.node_router.id
  description = "UpCloud router ID"
}

output "storage_id" {
  value       = upcloud_storage.root_disk.id
  description = "Root storage disk ID"
}

output "storage_size" {
  value       = upcloud_storage.root_disk.size
  description = "Storage size in GB"
}

output "firewall_rule_ids" {
  value       = upcloud_firewall_rules.node_firewall.firewall_rule[*].id
  description = "Firewall rule IDs"
}
