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

# Phase B1 (DRG default-route-table ownership proof -- see
# infrastructure/modules/network/gateways.tf's own comment on
# oci_core_drg_route_table.vcn_default for the full rationale). OpenTofu
# requires `import` blocks to live in the root module; Terragrunt copies
# this unit's module source into a flat working directory alongside its
# own generated files (verified: backend.tf/provider.tf already land
# there as siblings to the module's own .tf files), so a file generated
# here becomes part of that same root module at plan/apply time -- unlike
# putting the import block directly in gateways.tf, which would break
# examples/minimal/main.tf's use of this module as a CHILD module
# (verified empirically: OpenTofu rejects an import block inside a
# called module with "Import blocks are only allowed in the root
# module").
#
# Ownership-only: ONLY claims state ownership of the OCI-created VCN-
# attachments DRG route table (data.oci_core_drg_route_tables.vcn_default
# self-discovers its OCID -- no tenancy-specific value needed here).
# Does not attach the DRG to it, does not set remove_import_trigger, and
# does not touch the still-authoritative `inert` custom table or its
# attachment -- see the B1 gate report for what remains separately gated.
generate "drg_vcn_default_import" {
  path      = "drg_vcn_default_import.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
import {
  to = oci_core_drg_route_table.vcn_default
  id = data.oci_core_drg_route_tables.vcn_default.drg_route_tables[0].id
}
EOF
}
