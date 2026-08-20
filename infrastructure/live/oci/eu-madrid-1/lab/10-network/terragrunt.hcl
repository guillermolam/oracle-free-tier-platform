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

# REQ-NET-009 reuse-and-strip (ADR-0008 amendment; resolves GAP-NET-004):
# claims state ownership of the DRG's auto-created "VCN attachments"
# route table so the module can strip its default import distribution
# (remove_import_trigger on the resource in gateways.tf). No new DRG
# route table is created -- the tenancy's per-DRG route-table quota
# (limit = 2, both consumed by OCI's auto-created tables) is untouched.
#
# OpenTofu requires `import` blocks to live in the root module;
# Terragrunt copies this unit's module source into a flat working
# directory alongside its own generated files (verified: backend.tf /
# provider.tf already land there as siblings to the module's own .tf
# files), so a file generated here becomes part of that same root module
# at plan/apply time -- unlike putting the import block directly in
# gateways.tf, which would break examples/minimal/main.tf's use of this
# module as a CHILD module (verified empirically: OpenTofu rejects an
# import block inside a called module with "Import blocks are only
# allowed in the root module"). The OCID self-resolves via
# data.oci_core_drg_route_tables.vcn_default -- no tenancy-specific value
# here.
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
