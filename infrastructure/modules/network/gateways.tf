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

resource "oci_core_nat_gateway" "this" {
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
# hardcoded -- data.oci_core_services below.
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

resource "oci_core_drg_route_table" "inert" {
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

resource "oci_core_drg_attachment" "vcn" {
  drg_id             = oci_core_drg.this.id
  display_name       = "platform-drg-attachment"
  drg_route_table_id = oci_core_drg_route_table.inert.id

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
