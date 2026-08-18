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

variable "create_iam_policies" {
  type        = bool
  default     = false
  description = <<-EOT
    Whether to create the platform-ci-policy/platform-admin-policy IAM
    policies now. Defaults to false: this module's bootstrap principal is
    whichever existing tenancy `Administrators` member runs the first
    apply, and binding a policy to that same group would add no effective
    permission beyond its existing tenancy-wide grant while implying a
    separation of duties (CI vs admin) that doesn't exist until distinct
    principals do -- a dedicated human admin group and/or a federated CI
    identity (GitHub OIDC, EPIC-OCI-04). See SPEC-OCI-001's Non-Goals for
    the bootstrap-vs-steady-state identity distinction. Set true once
    ci_group_name/admin_group_name reference real, distinct principals.
  EOT
}

variable "ci_group_name" {
  type        = string
  default     = ""
  description = <<-EOT
    Name of the existing OCI IAM Group the CI/workflow identity (plan.yml's
    static credentials, REQ-OCI-006) belongs to. Only used when
    create_iam_policies is true. This module does NOT create IAM
    users/groups — group membership is an identity-governance decision
    made outside OpenTofu's Free-Tier bootstrap scope; this module only
    grants that existing group compartment-scoped policy rights (REQ-OCI-002).
  EOT

  validation {
    condition     = !var.create_iam_policies || length(trimspace(var.ci_group_name)) > 0
    error_message = "ci_group_name must not be empty when create_iam_policies is true."
  }
}

variable "admin_group_name" {
  type        = string
  default     = ""
  description = "Name of the existing OCI IAM Group the human administrator belongs to. Only used when create_iam_policies is true. Same non-creation rationale as ci_group_name."

  validation {
    condition     = !var.create_iam_policies || length(trimspace(var.admin_group_name)) > 0
    error_message = "admin_group_name must not be empty when create_iam_policies is true."
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

variable "create_dynamic_group" {
  type        = bool
  default     = false
  description = "Whether to create the Dynamic Group now. Defaults to false: REQ-OCI-003 requires the group exist before Talos/Flux instance principals need it, not before any instance exists -- until M2 compute lands, the match rule matches nothing, so creating it at 00-foundation time would deploy dead IAM machinery with no verifiable principal to review it against. Set true once M2 is imminent."
}
