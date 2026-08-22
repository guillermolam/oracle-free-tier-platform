# Compute module — Terraform version provider pinning
#
# Same rationale as infrastructure/modules/network/versions.tf: the module
# itself has no backend block. The live unit's Terragrunt root.hcl owns
# backend config (remote_state generate + migrate). A backend declaration
# here would silently collide with that convention.
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.27.0"
    }
  }
}
