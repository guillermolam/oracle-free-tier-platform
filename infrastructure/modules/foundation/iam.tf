# REQ-OCI-002: IAM policies scoped to the platform compartment only -- no
# statement below references the tenancy root as its target.
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

resource "oci_identity_policy" "ci" {
  compartment_id = oci_identity_compartment.platform.id
  name           = "platform-ci-policy"
  description    = "Least-privilege grant for the CI/workflow identity (REQ-OCI-002, REQ-OCI-006). Plan-equivalent (read/inspect) rights; apply rights are the human administrator's, not CI's, until a future PR explicitly designs CI-driven apply."

  statements = [
    "Allow group ${var.ci_group_name} to inspect all-resources in compartment ${oci_identity_compartment.platform.name}",
    "Allow group ${var.ci_group_name} to read all-resources in compartment ${oci_identity_compartment.platform.name}",
    # State backend read/write: the S3-Compatibility API authenticates as
    # this same OCI user via a Customer Secret Key (see root.hcl), but
    # native OCI IAM policy still governs what that user may do to the
    # bucket regardless of which API surface reaches it.
    "Allow group ${var.ci_group_name} to manage object-family in compartment ${oci_identity_compartment.platform.name} where target.bucket.name='${var.state_bucket_name}'",
  ]

  freeform_tags = { "provisioned-by" = "opentofu" }
}

resource "oci_identity_policy" "admin" {
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
}

# REQ-OCI-003: Dynamic Group matching Talos/Flux-managed instance
# principals. No compute exists yet (M1) -- this match rule targets "any
# instance in the platform compartment", valid OCI config that simply
# matches nothing until M2 introduces Talos instances. Defining the shape
# now means the network/compute modules don't need to touch IAM later.
resource "oci_identity_dynamic_group" "platform_instances" {
  compartment_id = var.tenancy_ocid # dynamic groups are always tenancy-scoped resources in OCI's model
  name           = var.dynamic_group_name
  description    = "Talos/Flux-managed instance principals in the platform compartment (REQ-OCI-003). Matches nothing until M2 compute exists."

  matching_rule = "ALL {instance.compartment.id = '${oci_identity_compartment.platform.id}'}"

  freeform_tags = { "provisioned-by" = "opentofu" }
}
