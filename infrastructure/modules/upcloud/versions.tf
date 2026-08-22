terraform {
  required_version = ">= 1.12.0"

  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "5.34.0"
    }
  }

  # No backend block, deliberately -- same rationale as
  # infrastructure/modules/foundation/versions.tf: Terragrunt's
  # `remote_state { generate { path = "backend.tf" } }` (root.hcl) owns
  # backend config once a live unit exists. A backend block here too
  # would be a second declaration, which OpenTofu rejects outright
  # ("Duplicate backend configuration").
}
