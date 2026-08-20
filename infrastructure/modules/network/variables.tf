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
}

# No CIDR variables, deliberately: REQ-NET-001/REQ-NET-002 mandate exact
# values ("MUST create ... using CIDR 10.10.0.0/16", "MUST create four
# subnets: Edge (10.10.10.0/24)..."), and ADR-0006 is explicit --
# "Preserve these exactly unless an approved ADR changes them." Exposing
# them as tunable variables would let a future environment silently
# deviate from the agreed trust-zone model without a superseding ADR.
# See vcn.tf/subnets.tf's locals.
