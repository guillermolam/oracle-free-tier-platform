terraform {
  required_version = ">= 1.12.0"

  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "5.34.0"
    }
  }
}

provider "upcloud" {
  # Credentials via UPCLOUD_API_TOKEN environment variable
}

module "upcloud_lab" {
  source = "../../"

  zone             = "es-mad1"
  plan             = "DEV-2xCPU-4GB"
  disk_size        = 60
  hostname         = "k8s-lab-1"
  admin_user       = "ubuntu"
  admin_ssh_key    = "" # Set via -var="admin_ssh_key=ssh-ed25519 ..." or via environment
  bootstrap_cidr   = "" # Restrict to your IP range if desired
  ssh_port         = 22
  network_name     = "k8s-lab-network"
  network_cidr     = "10.0.0.0/24"
  router_name      = "k8s-lab-router"
  storage_tier     = "standard"
  metadata_enabled = true

  tags = {
    environment = "lab"
    owner       = "platform"
    purpose     = "kubernetes-bootstrap"
  }
}

output "server" {
  value = {
    id       = module.upcloud_lab.server_id
    hostname = module.upcloud_lab.server_hostname
    ip       = module.upcloud_lab.server_ip_address
    zone     = module.upcloud_lab.server_zone
  }
}

output "network" {
  value = {
    id      = module.upcloud_lab.network_id
    address = module.upcloud_lab.network_address
  }
}

output "router" {
  value = {
    id = module.upcloud_lab.router_id
  }
}
