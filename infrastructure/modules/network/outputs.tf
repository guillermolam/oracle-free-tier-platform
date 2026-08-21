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
  value       = var.use_managed_nat ? one(oci_core_nat_gateway.this[*].id) : null
  description = "OCID of the NAT Gateway (REQ-NET-007), or null when use_managed_nat=false (Always Free default)."
}

output "sgw_id" {
  value       = var.use_managed_service_gateway ? one(oci_core_service_gateway.this[*].id) : null
  description = "OCID of the Service Gateway (REQ-NET-008), or null when use_managed_service_gateway=false (Always Free default)."
}

output "drg_id" {
  value       = oci_core_drg.this.id
  description = "OCID of the DRG (REQ-NET-009) -- attached to the VCN via the stripped auto-created DRG route table; see ADR-0008."
}

output "drg_route_table_id" {
  value       = oci_core_drg_route_table.vcn_default.id
  description = "OCID of the DRG route table the VCN attachment uses -- OCI's auto-created VCN-attachments table, reused and stripped of its import distribution (REQ-NET-009's inert mechanism; resolves GAP-NET-004). Empty until I21 populates it."
}

# SPEC-NET-003 Interfaces: route_table_ids{edge,management,workload,data}
# -- consumed by I04 (compute subnet attachment).
output "route_table_ids" {
  value       = { for zone, rt in oci_core_route_table.this : zone => rt.id }
  description = "Route table OCIDs keyed by trust-zone name (REQ-NET-011)."
}

# SPEC-NET-004 Interfaces: security_list_ids{edge,management,workload,data}
# and nsg_ids{ziti,ingress,control,worker,storage}.
output "security_list_ids" {
  value       = { for zone, sl in oci_core_security_list.this : zone => sl.id }
  description = "Baseline Security List OCIDs keyed by trust-zone name (REQ-NET-016)."
}

output "nsg_ids" {
  value       = { for purpose, nsg in oci_core_network_security_group.this : purpose => nsg.id }
  description = "Network Security Group OCIDs keyed by purpose: ziti, ingress, control, worker, storage (REQ-NET-017). All five NSGs are required by SPEC-NET-004; the compute module tolerates omitted keys via object optional() fields."
}
