# REQ-NET-001: exactly one VCN, exact CIDR. REQ-NET-002: four trust-zone
# subnets, exact CIDRs. ADR-0006 is explicit these are fixed, not
# per-environment tunables -- see variables.tf's comment. Hardcoded here
# as locals (not resource-inline literals) so subnets.tf and the `check`
# block below share one source of truth.
locals {
  vcn_cidr = "10.10.0.0/16"

  # Zone name -> CIDR. Matches ADR-0006's table and
  # docs/arch/cloud-deployment.mmd exactly (cross-checked against both
  # before writing this module, not assumed).
  subnet_cidrs = {
    edge       = "10.10.10.0/24"
    management = "10.10.20.0/24"
    workload   = "10.10.30.0/24"
    data       = "10.10.40.0/24"
  }

  # REQ-OCI-004: every resource under the platform compartment carries
  # Defined Tags. "Platform"/"Security" are the fixed tag-namespace names
  # infrastructure/modules/foundation creates (see its tags.tf) --
  # hardcoded here the same way foundation hardcodes them itself, not
  # re-exposed as a variable.
  network_defined_tags = {
    "Platform.Environment" = var.environment
    "Platform.System"      = var.platform_name
    "Platform.ManagedBy"   = "opentofu"
  }
}

# Self-check on the locals above, not on the deployed resources --
# guards against a future hand-edit introducing a CIDR outside the VCN, a
# duplicate, or a syntactically invalid value. Verified empirically
# against the pinned OpenTofu 1.12.5 that `cidrcontains`/`cidrhost` behave
# as expected (`tofu console`), not assumed. See network/README.md's
# "CIDR validation" section for what this can and cannot prove -- it does
# not attempt exhaustive interval arithmetic for partial overlaps that
# contain neither CIDR's own network address, a case that cannot arise
# among these four same-size, non-nested /24 allocations.
check "trust_zone_cidrs_are_valid_and_disjoint" {
  assert {
    condition = alltrue([
      for cidr in concat([local.vcn_cidr], values(local.subnet_cidrs)) : can(cidrhost(cidr, 0))
    ])
    error_message = "every VCN/subnet CIDR must be a syntactically valid CIDR block"
  }

  assert {
    condition = alltrue([
      for cidr in values(local.subnet_cidrs) : cidrcontains(local.vcn_cidr, cidr)
    ])
    error_message = "REQ-NET-002: every trust-zone subnet CIDR must fall within the VCN CIDR (${local.vcn_cidr})"
  }

  assert {
    condition     = length(distinct(values(local.subnet_cidrs))) == length(values(local.subnet_cidrs))
    error_message = "no two trust-zone subnets may share the same CIDR"
  }

  assert {
    condition = alltrue(flatten([
      for a_name, a_cidr in local.subnet_cidrs : [
        for b_name, b_cidr in local.subnet_cidrs :
        a_name == b_name || (!cidrcontains(a_cidr, b_cidr) && !cidrcontains(b_cidr, a_cidr))
      ]
    ]))
    error_message = "no two trust-zone subnets may overlap"
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [local.vcn_cidr]
  display_name   = "platform-vcn"
  dns_label      = "platform"

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    prevent_destroy = true

    # Same rationale as infrastructure/modules/foundation/state_backend.tf
    # -- OCI's built-in Oracle-Tags namespace auto-injects
    # CreatedBy/CreatedOn on every resource; ignore exactly those two
    # keys, never the whole defined_tags attribute.
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}
