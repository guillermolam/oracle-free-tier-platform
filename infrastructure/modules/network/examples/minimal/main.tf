# Minimal runnable reference. Not applied by CI (validate.yml only runs
# `tofu init -backend=false && tofu validate` against every modules/**
# and compositions/** directory containing main.tf -- this counts). Real
# usage is via Terragrunt: see
# infrastructure/live/oci/eu-madrid-1/lab/10-network/terragrunt.hcl.

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

module "network" {
  source = "../.."

  compartment_ocid = var.compartment_ocid
  environment      = "lab"
}

variable "compartment_ocid" {
  type        = string
  description = "Set via TF_VAR_compartment_ocid or -var, never hardcoded. In practice, infrastructure/modules/foundation's compartment_ocid output."
}

output "vcn_id" {
  value = module.network.vcn_id
}
