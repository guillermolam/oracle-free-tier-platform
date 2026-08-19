variable "compartment_ocid" {
  type        = string
  description = "OCID of the platform compartment (SPEC-OCI-001 output). This module places every resource here -- never the tenancy root."

  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.compartment_ocid))
    error_message = "compartment_ocid must be a valid compartment OCID (ocid1.compartment....)."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Only 'lab' exists today (infrastructure/README.md#tagging-contract)."

  validation {
    condition     = contains(["lab", "staging", "prod"], var.environment)
    error_message = "environment must be one of: lab, staging, prod."
  }
}

variable "platform_name" {
  type        = string
  default     = "oracle-free-tier-platform"
  description = "Platform.System defined-tag value -- matches infrastructure/modules/foundation's own default."
}

<<<<<<< HEAD
variable "use_managed_nat" {
  type        = bool
  description = "Create the managed NAT Gateway resource. Set to false when relying on the software-NAT instance (micro-nat) instead. Defaults to false since NAT gateway limit = 0 on Always Free."
  default     = false
}

variable "use_managed_service_gateway" {
  type        = bool
  description = "Create the managed Service Gateway resource. Set to false when relying on public endpoints through the NAT instance for OCI service access. Defaults to false since SGW limit = 0 on Always Free."
  default     = false
}

variable "nat_egress_target_ocid" {
  type        = string
  default     = null
  description = "OCID of the NAT egress target (the software-NAT instance micro-nat's private IP OCID from I04/compute). When set, the Management/Workload/Data 0.0.0.0/0 route rules use this instead of the managed NAT Gateway; null when using the managed gateway."

  validation {
    condition     = var.nat_egress_target_ocid == null || can(regex("^ocid1\\.privateip\\.", var.nat_egress_target_ocid))
    error_message = "nat_egress_target_ocid must be a private IP OCID (ocid1.privateip....) or null. A route rule's network_entity_id must reference a private IP, never a gateway or other route-compatible OCID."
  }
}

# Mutual-exclusivity guard: nat_egress_target_ocid takes precedence over
# use_managed_nat in routing.tf's resolution order (explicit > managed >
# discovered). Setting both silently creates a managed NAT gateway that no
# route references -- a wasted, never-used resource. Fail loudly instead.
check "nat_egress_target_and_managed_nat_are_mutually_exclusive" {
  assert {
    condition     = !(var.use_managed_nat && var.nat_egress_target_ocid != null)
    error_message = "nat_egress_target_ocid and use_managed_nat are mutually exclusive: the explicit private-IP target wins the resolution order, leaving any created managed NAT gateway unused. Set only one."
  }
}

variable "manage_inert_drg_route_table" {
  type        = bool
  default     = false
  description = <<-EOT
    Gates oci_core_drg_route_table.inert and oci_core_drg_attachment.vcn
    (REQ-NET-009/ADR-0008 Option B's custom empty DRG route table + its
    attachment). Defaults to false: a real apply against this tenancy hit
    a genuine OCI per-DRG-route-table-count service-limit error creating
    this 3rd table (a DRG auto-generates 2 default route tables that
    already consume the quota) -- see gateways.tf's own comment on this
    resource and GAP-NET-004 in the threat-model corpus. Does not affect
    oci_core_drg_route_table.vcn_default, which models an OCI-created
    table (no quota consumed) and is unconditional.
  EOT
}

# No CIDR variables, deliberately: REQ-NET-001/REQ-NET-002 mandate exact
# values ("MUST create ... using CIDR 10.10.0.0/16", "MUST create four
# subnets: Edge (10.10.10.0/24)..."), and ADR-0006 is explicit --
# "Preserve these exactly unless an approved ADR changes them." Exposing
# them as tunable variables would let a future environment silently
# deviate from the agreed trust-zone model without a superseding ADR.
# See vcn.tf/subnets.tf's locals.
