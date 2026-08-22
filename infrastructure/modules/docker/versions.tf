terraform {
  required_version = ">= 1.12.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }

  # No backend block, deliberately -- same rationale as
  # infrastructure/modules/foundation/versions.tf: Terragrunt's
  # `remote_state { generate { path = "backend.tf" } }` (root.hcl) owns
  # backend config once a live unit exists. A backend declaration here
  # would silently collide with that convention.
}
