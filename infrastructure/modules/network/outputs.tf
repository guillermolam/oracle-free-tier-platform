# REQ-NET-005: subnet OCIDs exposed keyed by zone name, for SPEC-NET-002
# (gateways) and I04 (compute) to consume.

output "vcn_id" {
  value       = oci_core_vcn.this.id
  description = "OCID of the platform VCN (SPEC-NET-001 Interfaces). Consumed by SPEC-NET-002 (gateways), SPEC-NET-003 (route tables), SPEC-NET-004 (NSGs/Security Lists)."
}

output "vcn_cidr" {
  value       = local.vcn_cidr
  description = "CIDR block of the platform VCN (REQ-NET-001)."
}

output "subnet_ids" {
  value       = { for zone, subnet in oci_core_subnet.this : zone => subnet.id }
  description = "Subnet OCIDs keyed by trust-zone name (edge, management, workload, data) -- REQ-NET-005."
}

output "subnet_cidrs" {
  value       = local.subnet_cidrs
  description = "Subnet CIDRs keyed by trust-zone name (REQ-NET-002)."
}

# SPEC-NET-002 Interfaces: igw_id, nat_id, sgw_id, drg_id -- consumed by
# SPEC-NET-003 (route tables, already wired internally in this module)
# and by I04/I21 once compute/hybrid connectivity exist.
output "igw_id" {
  value       = oci_core_internet_gateway.this.id
  description = "OCID of the Internet Gateway (REQ-NET-006)."
}

output "nat_id" {
  value       = oci_core_nat_gateway.this.id
  description = "OCID of the NAT Gateway (REQ-NET-007)."
}

output "sgw_id" {
  value       = oci_core_service_gateway.this.id
  description = "OCID of the Service Gateway (REQ-NET-008)."
}

output "drg_id" {
  value       = oci_core_drg.this.id
  description = "OCID of the DRG (REQ-NET-009) -- attached but inert until I21; see ADR-0008."
}

output "drg_route_table_id" {
  value       = oci_core_drg_route_table.inert.id
  description = "OCID of the DRG's own (empty, no-propagation) route table -- REQ-NET-009's inert mechanism."
}

# SPEC-NET-003 Interfaces: route_table_ids{edge,management,workload,data}
# -- consumed by I04 (compute subnet attachment).
output "route_table_ids" {
  value       = { for zone, rt in oci_core_route_table.this : zone => rt.id }
  description = "Route table OCIDs keyed by trust-zone name (REQ-NET-011)."
}

# SPEC-NET-004 Interfaces (partial -- security_list_ids only; nsg_ids
# awaits PR C3): security_list_ids{edge,management,workload,data}.
output "security_list_ids" {
  value       = { for zone, sl in oci_core_security_list.this : zone => sl.id }
  description = "Baseline Security List OCIDs keyed by trust-zone name (REQ-NET-016). NSG creation/output (REQ-NET-017) is PR C3."
}
