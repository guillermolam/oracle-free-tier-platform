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

# No CIDR variables, deliberately: REQ-NET-001/REQ-NET-002 mandate exact
# values ("MUST create ... using CIDR 10.10.0.0/16", "MUST create four
# subnets: Edge (10.10.10.0/24)..."), and ADR-0006 is explicit --
# "Preserve these exactly unless an approved ADR changes them." Exposing
# them as tunable variables would let a future environment silently
# deviate from the agreed trust-zone model without a superseding ADR.
# See vcn.tf/subnets.tf's locals.
