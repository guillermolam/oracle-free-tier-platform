# SPEC-NET-003 (REQ-NET-011..015): one route table per trust zone. No
# subnet uses the VCN's default route table (audited against the live
# tenancy before writing this file: all four subnets currently fall back
# to it, empty, since PR C created no explicit route table -- this file
# is what stops relying on that default).
#
# REQ-NET-012/013 is the binding security control: Edge is the ONLY route
# table that may ever reference the Internet Gateway. This is enforced
# structurally, not just by convention -- local.route_tables below is the
# single source every route table's rule set is built from, so there is
# exactly one place an Internet Gateway rule could be added to a
# non-Edge zone, and tests/routing.tftest.hcl asserts against it directly.
locals {
  # REQ-NET-014: all four zones route the OCI Services Network CIDR label
  # to the Service Gateway -- defined once, appended to every zone's rule
  # list below rather than repeated per zone.
  service_gateway_route_rule = {
    destination       = local.all_services_in_oracle_services_network.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
    description       = "REQ-NET-014: OCI services via Service Gateway"
  }

  route_tables = {
    edge = {
      display_name = "platform-edge-rt"
      route_rules = [
        {
          destination       = "0.0.0.0/0"
          destination_type  = "CIDR_BLOCK"
          network_entity_id = oci_core_internet_gateway.this.id
          description       = "REQ-NET-012: internet-bound traffic via Internet Gateway"
        },
        local.service_gateway_route_rule,
      ]
    }
    management = {
      display_name = "platform-management-rt"
      route_rules = [
        {
          destination       = "0.0.0.0/0"
          destination_type  = "CIDR_BLOCK"
          network_entity_id = oci_core_nat_gateway.this.id
          description       = "REQ-NET-013: internet-bound traffic via NAT Gateway only"
        },
        local.service_gateway_route_rule,
        # REQ-NET-015: reserved slot for a future DRG route once I21
        # activates hybrid connectivity (ADR-0008) -- intentionally
        # unpopulated here, not a placeholder resource, just documented
        # absence so I21 doesn't need to re-shape this route table later.
      ]
    }
    workload = {
      display_name = "platform-workload-rt"
      route_rules = [
        {
          destination       = "0.0.0.0/0"
          destination_type  = "CIDR_BLOCK"
          network_entity_id = oci_core_nat_gateway.this.id
          description       = "REQ-NET-013: internet-bound traffic via NAT Gateway only"
        },
        local.service_gateway_route_rule,
      ]
    }
    data = {
      display_name = "platform-data-rt"
      route_rules = [
        {
          destination       = "0.0.0.0/0"
          destination_type  = "CIDR_BLOCK"
          network_entity_id = oci_core_nat_gateway.this.id
          description       = "REQ-NET-013: internet-bound traffic via NAT Gateway only"
        },
        local.service_gateway_route_rule,
      ]
    }
  }
}

resource "oci_core_route_table" "this" {
  for_each = local.route_tables

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = each.value.display_name

  dynamic "route_rules" {
    for_each = each.value.route_rules
    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = route_rules.value.network_entity_id
      description       = route_rules.value.description
    }
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
