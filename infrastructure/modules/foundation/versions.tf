terraform {
  required_version = ">= 1.12.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.27.0"
    }
  }

  # Empty partial backend block: this module's backend config is supplied
  # externally, either by Terragrunt's `remote_state { generate { ... } }`
  # (root.hcl, once the state bucket exists) or by explicit
  # `-backend-config` flags during the REQ-OCI-007 two-phase bootstrap
  # (see README.md#bootstrap-runbook — phase 1 does not use this block at
  # all, phase 2 supplies it via -backend-config on `tofu init`).
  backend "s3" {}
}
