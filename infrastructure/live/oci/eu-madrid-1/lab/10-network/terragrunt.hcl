# SPEC-NET-001, ADR-0007's 10-network. Depends on 00-foundation for the
# platform compartment OCID -- see ADR-0007's dependency-direction diagram
# (00-foundation -> 10-network).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../modules/network"
}

dependency "foundation" {
  config_path = "../00-foundation"

  # Lets `terragrunt validate`/`plan` (and CI's plan.yml, before real
  # credentials exist) run without 00-foundation's real remote state
  # being reachable. `apply`/`destroy` are deliberately excluded --
  # never plan-and-apply this unit against a fabricated compartment OCID.
  mock_outputs = {
    compartment_ocid = "ocid1.compartment.oc1..aaaaaaaamockmockmockmockmockmockmockmockmockmockmockmockmock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  compartment_ocid = dependency.foundation.outputs.compartment_ocid
}
