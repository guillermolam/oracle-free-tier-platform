variable "tenancy_ocid" {
  type        = string
  description = "OCID of the tenancy (parent of the platform compartment). Sourced from env, never hardcoded — see infrastructure/live/common/account.hcl."

  validation {
    condition     = can(regex("^ocid1\\.tenancy\\.", var.tenancy_ocid))
    error_message = "tenancy_ocid must be a valid tenancy OCID (ocid1.tenancy....)."
  }
}

variable "compartment_name" {
  type        = string
  default     = "platform"
  description = "Name of the dedicated platform compartment (REQ-OCI-001)."
}

variable "compartment_description" {
  type        = string
  default     = "Platform compartment for oracle-free-tier-platform (SPEC-OCI-001)."
  description = "Description assigned to the platform compartment."
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
  description = "Platform.System defined-tag value."
}

variable "ci_group_name" {
  type        = string
  description = <<-EOT
    Name of the existing OCI IAM Group the CI/workflow identity (plan.yml's
    static credentials, REQ-OCI-006) belongs to. This module does NOT create
    IAM users/groups — group membership is an identity-governance decision
    made outside OpenTofu's Free-Tier bootstrap scope; this module only
    grants that existing group compartment-scoped policy rights (REQ-OCI-002).
  EOT

  validation {
    condition     = length(trimspace(var.ci_group_name)) > 0
    error_message = "ci_group_name must not be empty."
  }
}

variable "admin_group_name" {
  type        = string
  description = "Name of the existing OCI IAM Group the human administrator belongs to. Same non-creation rationale as ci_group_name."

  validation {
    condition     = length(trimspace(var.admin_group_name)) > 0
    error_message = "admin_group_name must not be empty."
  }
}

variable "state_bucket_name" {
  type        = string
  description = "Name of the dedicated OCI Object Storage bucket for OpenTofu remote state (REQ-OCI-005). Must match infrastructure/live/common/account.hcl's state_bucket_name so Terragrunt's generated backend config resolves to the same bucket this module creates."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid OCI bucket name (lowercase alphanumeric and hyphens, 3-63 chars)."
  }
}

variable "dynamic_group_name" {
  type        = string
  default     = "platform-instances"
  description = "Name of the Dynamic Group matching Talos/Flux-managed instance principals in the platform compartment (REQ-OCI-003). No instances exist yet (M1) -- the group's match rule targets 'any instance in this compartment', which is valid OCI config before any instance exists; it simply matches nothing until M2 compute lands."
}
