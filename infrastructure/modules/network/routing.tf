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
  # list below rather than repeated per zone. Null when the managed SGW is
  # disabled (use_managed_service_gateway = false, the Always Free default),
  # so the rule is filtered out of every zone's list rather than
  # referencing a count=0 resource.
  service_gateway_route_rule = var.use_managed_service_gateway ? {
    destination       = local.all_services_in_oracle_services_network.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this[0].id
    description       = "REQ-NET-014: OCI services via Service Gateway"
  } : null

  # REQ-NET-013: the Management/Workload/Data 0.0.0.0/0 route. Resolves to
  # (in order): an explicitly supplied software-NAT egress target
  # (nat_egress_target_ocid), else the managed NAT Gateway when it is
  # enabled, else -- when neither exists, i.e. the interim no-egress state
  # after the first 10-network apply and before I04/compute provisions
  # micro-nat -- null, which filters the rule out entirely. A count=0
  # oci_core_nat_gateway is never indexed here because the conditional
  # short-circuits: the "else" branch only evaluates when
  # use_managed_nat is true.
  nat_egress_route_rule = var.nat_egress_target_ocid != null ? {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = var.nat_egress_target_ocid
    description       = "REQ-NET-013: internet-bound traffic via NAT only"
    } : var.use_managed_nat ? {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this[0].id
    description       = "REQ-NET-013: internet-bound traffic via NAT only"
  } : null

  route_tables = {
    edge = {
      display_name = "platform-edge-rt"
      route_rules = [
        for r in [
          {
            destination       = "0.0.0.0/0"
            destination_type  = "CIDR_BLOCK"
            network_entity_id = oci_core_internet_gateway.this.id
            description       = "REQ-NET-012: internet-bound traffic via Internet Gateway"
          },
          local.service_gateway_route_rule,
        ] : r if r != null
      ]
    }
    management = {
      display_name = "platform-management-rt"
      route_rules = [
        for r in [
          local.nat_egress_route_rule,
          local.service_gateway_route_rule,
          # REQ-NET-015: reserved slot for a future DRG route once I21
          # activates hybrid connectivity (ADR-0008) -- intentionally
          # unpopulated here, not a placeholder resource, just documented
          # absence so I21 doesn't need to re-shape this route table later.
        ] : r if r != null
      ]
    }
    workload = {
      display_name = "platform-workload-rt"
      route_rules = [
        for r in [
          local.nat_egress_route_rule,
          local.service_gateway_route_rule,
        ] : r if r != null
      ]
    }
    data = {
      display_name = "platform-data-rt"
      route_rules = [
        for r in [
          local.nat_egress_route_rule,
          local.service_gateway_route_rule,
        ] : r if r != null
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
