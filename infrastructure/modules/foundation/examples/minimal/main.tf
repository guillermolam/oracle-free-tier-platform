# Minimal runnable reference. Not applied by CI (validate.yml only runs
# `tofu init -backend=false && tofu validate` against every modules/**
# and compositions/** directory containing main.tf -- this counts). Real
# usage is via Terragrunt: see
# infrastructure/live/oci/eu-madrid-1/lab/00-foundation/terragrunt.hcl.

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

module "foundation" {
  source = "../.."

  tenancy_ocid      = var.tenancy_ocid
  environment       = "lab"
  ci_group_name     = "platform-ci"
  admin_group_name  = "platform-admins"
  state_bucket_name = "oracle-free-tier-platform-tfstate"
}

variable "tenancy_ocid" {
  type        = string
  description = "Set via TF_VAR_tenancy_ocid or -var, never hardcoded."
}

output "compartment_ocid" {
  value = module.foundation.compartment_ocid
}
