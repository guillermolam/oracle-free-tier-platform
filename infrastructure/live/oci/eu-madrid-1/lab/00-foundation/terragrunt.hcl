# First real Terragrunt unit -- SPEC-OCI-001, ADR-0007's 00-foundation.
# Root of the dependency graph: 10-network and 20-security/* both depend
# on this unit's outputs (compartment_ocid, tag namespace names).
#
# BOOTSTRAP NOTE: this file's remote_state block (inherited from root.hcl)
# assumes the state bucket already exists. The FIRST TIME this unit is
# ever applied in a new environment, it doesn't -- that's what
# ../../../../../../modules/foundation/README.md#bootstrap-runbook's
# two-phase sequence resolves, run directly against the module (not
# through this Terragrunt unit) before this file is ever `terragrunt
# apply`'d. After that one-time bootstrap, this unit's own
# `terragrunt init` finds the bucket already populated at exactly the
# backend key it would generate (00-foundation/terraform.tfstate) and
# just uses it -- no migration needed here.

include "root" {
  # find_in_parent_folders() defaults to searching for a file literally
  # named terragrunt.hcl -- our root config is root.hcl (Terragrunt's own
  # recommended name, replacing terragrunt.hcl-as-root), so the filename
  # must be passed explicitly.
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../../modules/foundation"
}

inputs = {
  # tenancy_ocid and state_bucket_name are NOT redeclared here -- both
  # already arrive via root.hcl's `inputs = merge(...)` from
  # common/account.hcl, so there's exactly one place each is defined.
  #
  # create_iam_policies is NOT set here -- defaults to false
  # (variables.tf). The first apply uses the bootstrap principal
  # (existing tenancy Administrators membership) directly; it is not
  # granted a policy of its own (SPEC-OCI-001 Non-Goals). The names
  # below are placeholders for when create_iam_policies is deliberately
  # flipped to true against real, distinct CI/admin groups -- they do
  # not need to resolve to existing groups until then.
  ci_group_name    = get_env("OCI_CI_GROUP_NAME", "platform-ci")
  admin_group_name = get_env("OCI_ADMIN_GROUP_NAME", "platform-admins")
}
