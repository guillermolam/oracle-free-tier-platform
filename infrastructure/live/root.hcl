# Root Terragrunt configuration. Every unit under oci/<region>/<env>/
# includes this via `include "root" { path = find_in_parent_folders() }`.
#
# BOOTSTRAP EXCEPTION (REQ-OCI-007): the remote_state block below assumes
# the state bucket already exists. It does NOT exist until 00-foundation's
# own two-phase bootstrap has run once — see
# ../README.md#remote-state-bootstrap-sequence. 00-foundation's own
# terragrunt.hcl (created in the PR that scaffolds that unit, not this
# one) is the one unit that must NOT include this root.hcl's remote_state
# block on its first apply; it starts from local state
# (`-state=bootstrap.local.tfstate`) per that sequence's phase 1, then
# migrates into the bucket this block creates for every unit after it.
#
# CREDENTIAL NOTE: this backend authenticates against OCI Object Storage's
# S3-compatible API, which requires a Customer Secret Key (Access Key /
# Secret Key pair) — a DIFFERENT credential type from the OCI API key
# (tenancy/user OCID + fingerprint + private key) that plan.yml's existing
# secrets and the `oci` provider block below use. Provisioning that
# Customer Secret Key is part of 00-foundation's own bootstrap, not this
# file. access_key/secret_key below read the standard AWS_ACCESS_KEY_ID/
# AWS_SECRET_ACCESS_KEY env var names (the S3-backend machinery's own
# convention) rather than inventing repo-specific names.
#
# LOCKING NOTE: `use_lockfile = true` enables OpenTofu's native S3-backend
# locking (conditional writes via If-None-Match — no DynamoDB-equivalent
# needed). Verified from OpenTofu's own backend docs that this feature
# exists; NOT yet empirically verified that OCI's S3-compatible API honors
# If-None-Match conditional PUT semantics identically to AWS S3 — that
# must be confirmed in 00-foundation's own bootstrap PR against real OCI,
# not assumed here. If it turns out unsupported, remove `use_lockfile` and
# record the gap explicitly (single-maintainer risk profile makes
# unlocked state a lower-severity gap than for a multi-operator team, but
# it must be a documented decision, not a silent one).

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("common/account.hcl"))
  tags_vars    = read_terragrunt_config(find_in_parent_folders("common/tags.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  s3_compat_endpoint = "https://${local.account_vars.locals.tenancy_namespace}.compat.objectstorage.${local.region_vars.locals.region}.oci.customer-oci.com"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = local.account_vars.locals.state_bucket_name
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = local.region_vars.locals.region

    endpoints = {
      s3 = local.s3_compat_endpoint
    }

    access_key = get_env("AWS_ACCESS_KEY_ID", "")
    secret_key = get_env("AWS_SECRET_ACCESS_KEY", "")

    use_path_style              = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "oci" {
  region = "${local.region_vars.locals.region}"
}
EOF
}

inputs = merge(
  local.account_vars.locals,
  local.tags_vars.locals,
  local.region_vars.locals,
  local.env_vars.locals,
)
