# REQ-OCI-002: IAM policies scoped to the platform compartment only -- no
# statement below references the tenancy root as its target. Deferred by
# default (var.create_iam_policies = false): this module's bootstrap
# principal is whichever existing tenancy `Administrators` member runs
# the first apply, and binding either policy to that same group today
# would add no effective permission beyond its existing tenancy-wide
# grant (the built-in Tenant Admin Policy, untouched by this module)
# while implying a CI/admin separation of duties that does not exist
# until distinct principals do -- see SPEC-OCI-001's Non-Goals.
#
# What this module does NOT do: create OCI IAM Users or Groups. Group
# membership (who is actually in the CI/admin group) is an
# identity-governance decision outside OpenTofu's Free-Tier bootstrap
# scope -- var.ci_group_name/var.admin_group_name reference groups that
# already exist (the same OCI user plan.yml's existing static secrets
# authenticate as must already belong to one). See README.md#iam-bootstrap
# for the distinct, NOT-granted-here bootstrap-identity requirement (the
# tenancy-level rights needed to create THIS compartment in the first
# place -- a chicken-and-egg policy-scoped grant cannot authorize its own
# creation).

# Both policies enumerate specific resource-type families -- never
# all-resources -- matching exactly what THIS module creates. Expanding
# to a new resource type (e.g. once 10-network lands) means adding a new
# enumerated statement here, by design: the CI grant does not
# automatically broaden as new resource types appear elsewhere in the
# compartment (REQ-OCI-002's least-privilege intent, and SPEC-OCI-001's
# Security Requirements: "enumerate specific verbs/resource types, never
# manage all-resources" -- the same principle applies to "read
# all-resources", which would silently broaden CI's visibility into
# every future resource type without this module's own PR reviewing it).
resource "oci_identity_policy" "ci" {
  count = var.create_iam_policies ? 1 : 0

  compartment_id = oci_identity_compartment.platform.id
  name           = "platform-ci-policy"
  description    = "Least-privilege grant for the CI/workflow identity (REQ-OCI-002, REQ-OCI-006). Plan-equivalent (read) rights on exactly the resource types this module creates; apply rights are the human administrator's, not CI's, until a future PR explicitly designs CI-driven apply."

  statements = [
    "Allow group ${var.ci_group_name} to read compartments in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.ci_group_name} to read tag-namespaces in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.ci_group_name} to read dynamic-groups in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.ci_group_name} to read policies in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.ci_group_name} to read object-family in compartment ${oci_identity_compartment.platform.name}",
    # State backend read/write: the S3-Compatibility API authenticates as
    # this same OCI user via a Customer Secret Key (see root.hcl), but
    # native OCI IAM policy still governs what that user may do to the
    # bucket regardless of which API surface reaches it.
    "Allow group ${var.ci_group_name} to manage object-family in compartment ${oci_identity_compartment.platform.name} where target.bucket.name='${var.state_bucket_name}'",
  ]

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.foundation_defined_tags
}

resource "oci_identity_policy" "admin" {
  count = var.create_iam_policies ? 1 : 0

  compartment_id = oci_identity_compartment.platform.id
  name           = "platform-admin-policy"
  description    = "Human administrator: manage rights for the resources THIS module creates, scoped to the platform compartment (REQ-OCI-002). Does not grant tenancy-level rights -- see README.md#iam-bootstrap for the separate, undocumented-here bootstrap-identity requirement."

  statements = [
    "Allow group ${var.admin_group_name} to manage compartments in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.admin_group_name} to manage tag-namespaces in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.admin_group_name} to manage dynamic-groups in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.admin_group_name} to manage policies in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.admin_group_name} to manage object-family in compartment ${oci_identity_compartment.platform.name}",
  ]

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.foundation_defined_tags
}

# REQ-OCI-003: Dynamic Group matching Talos/Flux-managed instance
# principals. Deferred by default (var.create_dynamic_group = false): no
# compute exists yet (M1), so the match rule below would target "any
# instance in the platform compartment" and match literally nothing --
# valid OCI config, but dead IAM machinery with no principal to review it
# against until M2 introduces Talos instances. Set create_dynamic_group =
# true once M2 is imminent instead of deploying this ahead of need.
resource "oci_identity_dynamic_group" "platform_instances" {
  count = var.create_dynamic_group ? 1 : 0

  compartment_id = var.tenancy_ocid # dynamic groups are always tenancy-scoped resources in OCI's model
  name           = var.dynamic_group_name
  description    = "Talos/Flux-managed instance principals in the platform compartment (REQ-OCI-003). Matches nothing until M2 compute exists."

  matching_rule = "ALL {instance.compartment.id = '${oci_identity_compartment.platform.id}'}"

  freeform_tags = { "provisioned-by" = "opentofu" }
  defined_tags  = local.foundation_defined_tags
}
