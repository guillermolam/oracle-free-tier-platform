# SPEC-NET-002 (REQ-NET-006..010): Internet Gateway, NAT Gateway, Service
# Gateway, and an inert Dynamic Routing Gateway. Route-table wiring is
# routing.tf (SPEC-NET-003) -- this file only creates the gateway objects
# themselves, per SPEC-NET-002's own Non-Goals.

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "platform-igw"
  enabled        = true

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# REQ-NET-007: NAT Gateway. Count-driven rather than unconditional because
# the Always Free tier has a hard limit of 0 NAT gateways
# (nat-gateway-count: 0 on this account) -- the software-NAT instance
# (I04/compute micro-nat) is the real egress path, and this managed
# resource exists only when use_managed_nat is explicitly true.
resource "oci_core_nat_gateway" "this" {
  count          = var.use_managed_nat ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "platform-nat"

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# REQ-NET-008: private access to OCI services (Object Storage, KMS,
# Logging, Monitoring) without traversing the internet. The Services
# Network CIDR label is a per-region OCI construct, looked up rather than
# hardcoded -- data.oci_core_services below. Like the NAT Gateway, the
# managed Service Gateway is count-driven because the Always Free tier
# caps this account at 0 service gateways; the data source is still
# declared unconditionally so the route rules can resolve the CIDR label
# either way, but the resource itself exists only when
# use_managed_service_gateway is explicitly true.
data "oci_core_services" "all" {}

locals {
  # The OCI Services Network exposes exactly one "All <REGION> Services In
  # Oracle Services Network" entry per region -- matched by name pattern,
  # not a hardcoded per-region ID, so this module stays region-neutral.
  all_services_in_oracle_services_network = one([
    for s in data.oci_core_services.all.services : s
    if can(regex("All .* Services In Oracle Services Network", s.name))
  ])
}

resource "oci_core_service_gateway" "this" {
  count          = var.use_managed_service_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "platform-sgw"

  services {
    service_id = local.all_services_in_oracle_services_network.id
  }

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# REQ-NET-009/ADR-0008 (Option B): DRG created and attached now, reserved
# for I21 hybrid connectivity, but INERT in M1 -- "inert" means the DRG's
# own route table holds zero route rules and has no import route
# distribution configured (no propagation), not that the attachment
# itself is absent. OCI requires every DRG attachment to reference a DRG
# route table (an attachment can't have "no association"), so this empty
# table IS the inert mechanism, not a placeholder to fill in later without
# review.
resource "oci_core_drg" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "platform-drg"

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# Phase B1 (DRG default-route-table ownership proof, ADR-0008 amendment
# under evaluation -- NOT yet decided/merged): models OCI's own
# auto-generated "VCN attachments" DRG route table for state ownership
# ONLY. Every DRG OCI creates auto-generates two of these
# (vcn-attachments, rpc/vc/ipsec-attachments) with their own import route
# distribution already active -- consuming this tenancy's per-DRG
# route-table quota before any custom table (like `inert` below) can be
# added, which is what caused PR C2's real partial-apply failure on a
# real OCI service-limit error. This block does NOT change REQ-NET-009's
# still-authoritative custom-inert-table design below, does NOT attach
# the DRG to this table, and does NOT set remove_import_trigger --
# purely an ownership-only import target for a separately-gated proof.
# Self-discovered via drg_id + OCI's own fixed auto-generated display
# name (same self-discovery pattern as
# local.all_services_in_oracle_services_network above) -- no
# tenancy-specific OCID flows through this module's inputs. The `import`
# block that actually claims ownership lives in the Terragrunt live
# layer (10-network/terragrunt.hcl's generate block), not here: OpenTofu
# requires import blocks in the root module only, and this module is
# also instantiated as a CHILD module by examples/minimal/main.tf
# (verified empirically -- an import block placed directly in a called
# module errors with "Import blocks are only allowed in the root
# module").
data "oci_core_drg_route_tables" "vcn_default" {
  drg_id       = oci_core_drg.this.id
  display_name = "Autogenerated Drg Route Table for VCN attachments"
}

resource "oci_core_drg_route_table" "vcn_default" {
  drg_id       = oci_core_drg.this.id
  display_name = "Autogenerated Drg Route Table for VCN attachments"

  # import_drg_route_distribution_id and is_ecmp_enabled deliberately
  # unset: both are Optional+Computed, so OpenTofu adopts whatever the
  # live object currently has instead of trying to change either
  # (verified: a real import against the live object, and a second,
  # independent plan afterward, both show zero diff).

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# Gated by var.manage_inert_drg_route_table (default false): a real
# apply attempt against this tenancy failed here with an OCI
# per-DRG-route-table-count service-limit error -- creating a DRG
# auto-generates 2 default route tables (confirmed live: "Autogenerated
# Drg Route Table for VCN attachments" / "...for RPC, VC, and IPSec
# attachments"), consuming the whole quota before this 3rd custom table
# can be added. This is the exact problem oci_core_drg_route_table.
# vcn_default above is evaluating an alternative to (reuse the
# OCI-created default table instead of requesting a 3rd quota slot) --
# see GAP-NET-004 in docs/03-threat-model/model/instances/network.yaml
# and the B1/B2 gate reports for that evaluation's status. Left
# code-present but disabled (not deleted) so ADR-0008 Option B's
# still-authoritative design remains available/reversible without an
# ADR amendment; flip the variable once either a real quota increase or
# the vcn_default alternative is decided and proven.
resource "oci_core_drg_route_table" "inert" {
  count = var.manage_inert_drg_route_table ? 1 : 0

  drg_id       = oci_core_drg.this.id
  display_name = "platform-drg-rt-inert"

  # import_drg_route_distribution_id deliberately unset: no route
  # distribution means no propagation into this table -- REQ-NET-009's
  # "propagation disabled" requirement. No oci_core_drg_route_table_route_rule
  # resource references this table either, so it also carries zero static
  # routes. Both together are what ADR-0008 means by "present but inert."

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# Gated with oci_core_drg_route_table.inert above -- OCI requires every
# DRG attachment to reference a DRG route table, so this can only exist
# once that table does. REQ-NET-009 requires the DRG to be attached, but
# while this stays disabled the DRG itself remains genuinely unattached
# (not attached-to-nothing) -- an accurate reflection of current
# deployment capability, not a REQ-NET-009 violation-in-progress
# (nothing in M1-M10 depends on the attachment existing yet -- ADR-0008's
# own Reversibility section).
resource "oci_core_drg_attachment" "vcn" {
  count = var.manage_inert_drg_route_table ? 1 : 0

  drg_id             = oci_core_drg.this.id
  display_name       = "platform-drg-attachment"
  drg_route_table_id = oci_core_drg_route_table.inert[0].id

  network_details {
    type = "VCN"
    id   = oci_core_vcn.this.id
  }

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}
