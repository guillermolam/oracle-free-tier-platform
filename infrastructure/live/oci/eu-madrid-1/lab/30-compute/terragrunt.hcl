# terragrunt.hcl for 30-compute (SPEC-COMP-001)
#
# Depends on 10-network for subnet IDs and NSG authorisation. The compute
# module creates the software‑NAT instance (micro-nat) and Talos nodes.
#
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../modules/compute"
}

dependency "foundation" {
  config_path = "../00-foundation"
  mock_outputs = {
    compartment_ocid = "ocid1.compartment.oc1..aaaaaaaamockmockmockmockmockmockmockmockmockmockmockmockmock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "network" {
  config_path = "../10-network"
  mock_outputs = {
    subnet_ids = {
      edge     = "ocid1.subnet.oc1..mockmockmockmockmockmockmockmockmockmockmockmockmock"
      management = "ocid1.subnet.oc1..mockmockmockmockmockmockmockmockmockmockmockmockmock"
      workload = "ocid1.subnet.oc1..mockmockmockmockmockmockmockmockmockmockmockmockmock"
      data     = "ocid1.subnet.oc1..mockmockmockmockmockmockmockmockmockmockmockmockmock"
    }
    nsg_ids = {
      ziti    = "ocid1.networksecuritygroup.oc1..mockmockmockmockmockmockmockmockmockmockmock"
      ingress = "ocid1.networksecuritygroup.oc1..mockmockmockmockmockmockmockmockmockmockmock"
      control = "ocid1.networksecuritygroup.oc1..mockmockmockmockmockmockmockmockmockmockmock"
      worker  = "ocid1.networksecuritygroup.oc1..mockmockmockmockmockmockmockmockmockmockmock"
      storage = "ocid1.networksecuritygroup.oc1..mockmockmockmockmockmockmockmockmockmockmock"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  compartment_ocid = dependency.foundation.outputs.compartment_ocid
  environment      = "lab"
  platform_name    = "oracle-free-tier-platform"
  subnet_ids       = dependency.network.outputs.subnet_ids
  nsg_ids = {
    ziti    = dependency.network.outputs.nsg_ids.ziti
    ingress = dependency.network.outputs.nsg_ids.ingress
    control = dependency.network.outputs.nsg_ids.control
    worker  = dependency.network.outputs.nsg_ids.worker
    storage = dependency.network.outputs.nsg_ids.storage
  }
}
