# Tag-based discovery of the software-NAT instance (I04/compute micro-nat).
#
# REQ-NET-013: Management/Workload/Data route 0.0.0.0/0 to micro-nat's
# private IP OCID instead of a managed NAT Gateway -- Always Free caps this
# account at 0 NAT gateways, so the managed resource cannot be the real
# egress path. This module must NOT form a Terragrunt dependency on the
# 30-compute state unit to learn that target (30-compute consumes this
# module's subnet_ids; a dependency in the other direction would be
# circular). Instead the target is discovered at runtime from OCI by
# freeform tag, so the ordering is purely bootstrap sequencing: first
# 10-network apply (micro-nat absent -> no egress route at all, the
# accepted interim state), then 30-compute (micro-nat created and tagged),
# then 10-network reapply (lookup now resolves, egress route appears).
data "oci_core_instances" "software_nat" {
  compartment_id = var.compartment_ocid
}

locals {
  # Every instance in the platform compartment, narrowed to the one tagged
  # role=software-nat. try() guards the lookup so the interim no-egress
  # state (before micro-nat exists) is an empty selection, not a plan-time
  # error; it also tolerates a missing freeform_tags map on unrelated
  # instances. one() fails loudly if more than one instance ever carries
  # the tag -- a genuine misconfiguration we want surfaced.
  software_nat_instance = try(one([
    for i in data.oci_core_instances.software_nat.instances :
    i if try(i.freeform_tags["role"], "") == "software-nat"
  ]), null)

  # A route rule's network_entity_id must name the private IP OCID, not the
  # instance OCID. Resolved by matching micro-nat's primary private IP
  # address. The lookup deliberately omits a subnet_id filter: the subnet
  # resource depends on the route tables (subnet.route_table_id ->
  # oci_core_route_table.this), and the route tables depend on this lookup
  # via local.nat_egress_route_rule -- adding subnet_id here would close a
  # dependency cycle at plan time. ip_address alone is unambiguous for this
  # platform's single tagged micro-nat; if that ever changes, the explicit
  # nat_egress_target_ocid input is the escape hatch. count on the data
  # source is driven by the instance lookup, so nothing is queried until
  # micro-nat exists.
  software_nat_private_ip_ocid = try(
    one(flatten(data.oci_core_private_ips.software_nat[*].private_ips)).id,
    null
  )
}

data "oci_core_private_ips" "software_nat" {
  count      = local.software_nat_instance != null ? 1 : 0
  ip_address = local.software_nat_instance.private_ip
}
