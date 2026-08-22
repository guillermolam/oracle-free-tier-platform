# Minimal runnable reference. Not applied by CI (validate.yml only runs
# `tofu init -backend=false && tofu validate` against every modules/**
# and compositions/** directory containing main.tf -- this counts). Real
# usage is via Terragrunt: see
# infrastructure/live/oci/eu-madrid-1/lab/30-compute/terragrunt.hcl.

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.27.0"
    }
  }
}

provider "oci" {
  region = "eu-madrid-1"
}

# Subnet IDs must match the four trust-zone subnets created by 10-network.
# Values are data sources from that module; omitted here for brevity.
locals {
  subnet_ids = {
    edge       = "ocid1.subnet.oc1..EXAMPLEEDGE"
    management = "ocid1.subnet.oc1..EXAMPLEMGMT"
    workload   = "ocid1.subnet.oc1..EXAMPLEWORKLOAD"
    data       = "ocid1.subnet.oc1..EXAMPLEDATA"
  }
}

module "compute" {
  source = "../.."

  compartment_ocid = var.compartment_ocid
  environment      = "lab"
  platform_name    = "oracle-free-tier-platform"
  subnet_ids       = local.subnet_ids
}

variable "compartment_ocid" {
  type        = string
  description = "Set via TF_VAR_compartment_ocid or -var, never hardcoded. In practice, infrastructure/modules/foundation's compartment_ocid output."
}
