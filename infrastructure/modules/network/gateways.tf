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

# REQ-NET-009/ADR-0008 (Option B, amended): DRG created and attached now,
# reserved for I21 hybrid connectivity, but INERT in M1 -- "inert" means
# the DRG route table used by the attachment holds zero route rules and
# has no import route distribution (no propagation), and the attachment
# itself advertises nothing back. OCI requires every DRG attachment to
# reference a DRG route table (an attachment can't have "no association"),
# so the empty table IS the inert mechanism, not a placeholder to fill in
# later without review.
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

# REQ-NET-009 inert mechanism, reuse-and-strip form (ADR-0008 amendment;
# resolves GAP-NET-004): creating a DRG makes OCI auto-generate 2 route
# tables per DRG, consuming this tenancy's whole per-DRG route-table
# quota (limit = 2) -- so a third custom "inert" table cannot be created
# (real apply failure, PR C2). Instead of fighting the quota, this
# resource takes state ownership of the auto-created "VCN attachments"
# table (imported at the Terragrunt live layer -- import blocks are
# root-module-only, and this module is also a child in examples/minimal)
# and strips its default "accept all routes" import distribution via
# remove_import_trigger. No new table is created, so no quota is
# consumed. Self-discovered via drg_id + OCI's own fixed auto-generated
# display name (same self-discovery pattern as
# local.all_services_in_oracle_services_network above) -- no
# tenancy-specific OCID flows through this module's inputs.
# The only in-repo reference to this data source lives in the Terragrunt
# live layer's generated import block (root-module-only; see
# 10-network/terragrunt.hcl), invisible to per-module tflint runs.
# tflint-ignore: terraform_unused_declarations
data "oci_core_drg_route_tables" "vcn_default" {
  drg_id       = oci_core_drg.this.id
  display_name = "Autogenerated Drg Route Table for VCN attachments"
}

resource "oci_core_drg_route_table" "vcn_default" {
  drg_id       = oci_core_drg.this.id
  display_name = "Autogenerated Drg Route Table for VCN attachments"

  # Strips OCI's default import route distribution ("accept all routes,
  # no match criteria") -- after this, nothing propagates into the table.
  # remove_import_trigger is Optional+Updatable and, once flipped, sets
  # import_drg_route_distribution_id to null (per the oracle/oci provider
  # docs for oci_core_drg_route_table). Zero static route rules are ever
  # added (no oci_core_drg_route_table_route_rule resource references
  # this table), so the table is empty AND non-propagating -- ADR-0008's
  # "present but inert."
  remove_import_trigger = true

  # import_drg_route_distribution_id and is_ecmp_enabled deliberately
  # unset: both are Optional+Computed, so OpenTofu adopts whatever the
  # live object currently has after the strip (null / false) instead of
  # trying to change either.

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.network_defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# REQ-NET-009: DRG attached to the VCN via the stripped auto-created
# table above. remove_export_drg_route_distribution_trigger nulls the
# attachment's default export route distribution (per the oracle/oci
# provider docs for oci_core_drg_attachment: it "gets a default value on
# creation" and can only be nulled via this trigger), so nothing is
# advertised to the attachment either -- the path is inert in both
# directions until I21.
resource "oci_core_drg_attachment" "vcn" {
  drg_id             = oci_core_drg.this.id
  display_name       = "platform-drg-attachment"
  drg_route_table_id = oci_core_drg_route_table.vcn_default.id

  remove_export_drg_route_distribution_trigger = true

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
