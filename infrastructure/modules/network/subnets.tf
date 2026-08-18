# REQ-NET-003: Management, Workload, and Data MUST NOT allow public IP.
# REQ-NET-004: only Edge MAY allow public IP -- allowed here at the
# subnet level, not assigned to anything, since no compute/ingress/
# OpenZiti-edge-router VNIC exists yet (that attachment is SPEC-NET-004
# scope, explicitly out of this module's Non-Goals for now).
#
# No route_table_id/security_list_ids set on any subnet: each gets OCI's
# auto-created default route table (empty -- no gateway routes exist
# until SPEC-NET-002/003 add them) and default security list. This is
# what "the module must not silently attach IGW/NAT/SGW routes yet"
# means in practice -- there is nothing to attach until those Specs'
# modules exist, so the safe default is exactly what OCI already does
# for an unconfigured subnet.
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

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = each.value
  display_name   = "platform-${each.key}"
  dns_label      = each.key

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
