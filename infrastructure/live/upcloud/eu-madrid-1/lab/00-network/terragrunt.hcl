# terragrunt.hcl for UpCloud network infrastructure (00-network)
#
# Creates UpCloud network, router, and storage prerequisites for node
# provisioning. No dependencies — this is the foundational unit.
#
# This unit is intentionally minimal: network and router only. Server
# provisioning is delegated to 10-compute with an explicit dependency on
# this unit's outputs.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../modules/upcloud"
}

inputs = {
  zone         = "es-mad1"
  plan         = "DEV-2xCPU-4GB"
  disk_size    = 60
  hostname     = "k8s-network-0"
  admin_user   = "ubuntu"
  ssh_port     = 22
  network_name = "${local.platform_name}-network"
  network_cidr = "10.0.0.0/24"
  router_name  = "${local.platform_name}-router"

  tags = merge(
    local.tags,
    {
      unit = "00-network"
    }
  )
}

locals {
  platform_name = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.platform_name
  tags          = read_terragrunt_config(find_in_parent_folders("common/tags.hcl")).locals.tags
}
