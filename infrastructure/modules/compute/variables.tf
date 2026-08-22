# Compute module — input contract (SPEC-COMP-001)
#
# All inputs follow the same pattern as foundation/network: required
# compartment_ocid and environment, optional platform_name defaulting to
# "oracle-free-tier-platform". No CIDR variables — subnet_ids come keyed
# by zone from 10-network's output, keeping the source-of-truth on that
# module. The Talos image is resolved dynamically by display_name filter
# against images already imported into the compartment (see data.tf).

variable "compartment_ocid" {
  description = "OCI compartment OCID (from 00-foundation)."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.compartment_ocid))
    error_message = "compartment_ocid must be a valid OCI compartment OCID."
  }
}

variable "environment" {
  description = "Environment name: lab, staging, or prod."
  type        = string

  validation {
    condition     = contains(["lab", "staging", "prod"], var.environment)
    error_message = "environment must be one of: lab, staging, prod."
  }
}

variable "platform_name" {
  description = "Platform name used for resource tagging and display-name prefixing."
  type        = string
  default     = "oracle-free-tier-platform"
}

# Subnets are consumed from the network module's output, keyed by zone.
# This keeps the CIDR/zone contract as a single source of truth.

variable "subnet_ids" {
  description = "Subnet IDs keyed by zone: edge, management, workload, data (from 10-network)."
  type = object({
    edge       = string
    management = string
    workload   = string
    data       = string
  })
}

# NSG IDs (optional — if provided, micro-nat will be attached to its NSG).
# SPEC-NET-004's NSGs are PR C3; this module tolerates null NSGs for the
# interim state where only Security List baselines exist.

variable "nsg_ids" {
  description = "NSG OCIDs keyed by purpose: ziti, ingress, control, worker, storage (from SPEC-NET-004)."
  type = object({
    ziti    = optional(string)
    ingress = optional(string)
    control = optional(string)
    worker  = optional(string)
    storage = optional(string)
  })
  default = {}
}

# --- Micro-NAT instance parameters ---

variable "micro_nat_shape" {
  description = "Shape for the software-NAT instance. Fixed to E2.1.Micro per REQ-COMP-001."
  type        = string
  default     = "VM.Standard.E2.1.Micro"

  validation {
    condition     = var.micro_nat_shape == "VM.Standard.E2.1.Micro"
    error_message = "Micro-NAT shape must be VM.Standard.E2.1.Micro (free x86 AMD) per REQ-COMP-001."
  }
}

variable "micro_boot_volume_vpus_per_gb" {
  description = "VPUs per GB for micro-nat boot volume. Minimum viable value to save block volume quota."
  type        = number
  default     = 1 # BEST_EFFORT tier — saves quota since NAT forwarding has no IOPS requirement.
}

variable "micro_boot_volume_size_in_gbs" {
  description = "Boot volume size in GB for micro-nat. OCI minimum ~50 GB."
  type        = number
  default     = 50
}

# --- Talos node shared parameters ---

variable "talos_version" {
  description = "Pinned Talos Linux version to deploy. Must be verified-to-boot-on-OCI for A1.Flex ARM64 (paravirtualized UEFI_64)."
  type        = string
  default     = "v1.9.4"

  validation {
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+$", var.talos_version))
    error_message = "talos_version must be a semantic version string prefixed with 'v' (e.g., v1.9.4)."
  }
}

variable "talos_cpu_cores" {
  description = "Total CPU cores across all Talos nodes. Must equal 4 (Always Free ARM envelope)."
  type        = number
  default     = 4

  validation {
    condition     = var.talos_cpu_cores == 4
    error_message = "Talos total CPU cores must be 4 (Always Free ARM envelope)."
  }
}

variable "talos_memory_gbs" {
  description = "Total RAM across all Talos nodes in GB. Must equal 24 (Always Free ARM envelope)."
  type        = number
  default     = 24

  validation {
    condition     = var.talos_memory_gbs == 24
    error_message = "Talos total memory must be 24 GB (Always Free ARM envelope)."
  }
}

variable "talos_boot_volume_vpus_per_gb" {
  description = "VPUs per GB for Talos boot volumes. Balanced tier ensures reliable OS boot."
  type        = number
  default     = 10 # BALANCED tier (minimum for performance) — OS partitions need some IOPS.
}

variable "talos_boot_volume_size_in_gbs" {
  description = "Boot volume size in GB for each Talos node. OCI minimum 50 GB."
  type        = number
  default     = 50
}
