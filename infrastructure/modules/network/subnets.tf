# REQ-NET-003: Management, Workload, and Data MUST NOT allow public IP.
# REQ-NET-004: only Edge MAY allow public IP -- allowed here at the
# subnet level, not assigned to anything, since no compute/ingress/
# OpenZiti-edge-router VNIC exists yet (that attachment is SPEC-NET-004
# scope, explicitly out of this module's Non-Goals for now).
#
# route_table_id: each subnet now uses its own zone's explicit route
# table (REQ-NET-011, routing.tf) instead of the VCN's default -- audited
# against the live tenancy before this change: all four subnets
# previously fell back to the default route table (empty, 0 rules), so
# this is an in-place update (route_table_id changes from the implicit
# default to an explicit OCID), not a replacement -- OCI subnets don't
# force-replace on route_table_id changes.
#
# security_list_ids: each subnet now uses its own zone's baseline
# Security List (security_lists.tf, REQ-NET-016/018) instead of the VCN
# default. Audited against the live tenancy before this change: the
# default list allowed SSH (22/tcp) and ICMP from 0.0.0.0/0 on every
# subnet -- harmless while no subnet had a route to anywhere, but
# gateways.tf/routing.tf (same PR) make Edge specifically IGW-routable,
# which would have left a real transitional exposure if this file
# shipped without its own Security List baseline.
locals {
  subnet_public_allowed = {
    edge       = true
    management = false
    workload   = false
    data       = false
  }
}

resource "oci_core_subnet" "this" {
  for_each = local.subnet_cidrs

  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.this.id
  cidr_block        = each.value
  display_name      = "platform-${each.key}"
  dns_label         = each.key
  route_table_id    = oci_core_route_table.this[each.key].id
  security_list_ids = [oci_core_security_list.this[each.key].id]

  prohibit_public_ip_on_vnic = !local.subnet_public_allowed[each.key]

  freeform_tags = { "provisioned-by" = "opentofu", "trust-zone" = each.key }
  defined_tags  = local.network_defined_tags

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}
