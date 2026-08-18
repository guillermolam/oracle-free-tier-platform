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
