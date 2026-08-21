# terragrunt.hcl for UpCloud compute infrastructure (10-compute)
#
# Creates Kubernetes worker node(s) and firewall policies.
# Depends on 00-network for network_id and router_id outputs.
#
# The 00-network unit creates network infrastructure; this unit reuses that
# infrastructure to provision compute instances with explicit dependency
# blocking and mock outputs for dry-run planning.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../modules/upcloud"
}

dependency "network" {
  config_path = "../00-network"
  mock_outputs = {
    network_id = "mock-network-id"
    router_id  = "mock-router-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  zone         = "es-mad1"
  plan         = "DEV-2xCPU-4GB"
  disk_size    = 60
  hostname     = "k8s-worker-1"
  admin_user   = "ubuntu"
  ssh_port     = 22
  network_name = "${local.platform_name}-network"
  network_cidr = "10.0.0.0/24"
  router_name  = "${local.platform_name}-router"

  tags = merge(
    local.tags,
    {
      unit = "10-compute"
      role = "worker"
    }
  )
}

locals {
  platform_name = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.platform_name
  tags          = read_terragrunt_config(find_in_parent_folders("common/tags.hcl")).locals.tags
}
