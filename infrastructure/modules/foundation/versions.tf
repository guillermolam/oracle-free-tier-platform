terraform {
  required_version = ">= 1.12.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.27.0"
    }
  }

  # No backend block, deliberately: this module owns resource logic only,
  # never a backend opinion (ADR-0001's Terragrunt/OpenTofu ownership
  # split). Terragrunt's `remote_state { generate { path = "backend.tf" }
  # }` (root.hcl) writes the real backend config into the working
  # directory at plan/apply time -- a `backend "s3" {}` block declared
  # here too would be a SECOND backend declaration in the same module,
  # which OpenTofu rejects outright ("Duplicate backend configuration"),
  # confirmed by reproducing it locally, not assumed. REQ-OCI-007's
  # bootstrap (see README.md#bootstrap-runbook) writes its own temporary
  # backend.tf into an untracked scratch copy of this module for exactly
  # this reason -- never into this file.
}
