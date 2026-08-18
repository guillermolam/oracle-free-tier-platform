# Root Terragrunt configuration. Every unit under oci/<region>/<env>/
# includes this via `include "root" { path = find_in_parent_folders() }`.
#
# BOOTSTRAP EXCEPTION (REQ-OCI-007): the remote_state block below assumes
# the state bucket already exists. It does NOT exist until
# modules/foundation's own two-phase bootstrap has run once, directly
# against that module (NOT through this Terragrunt unit) -- see
# modules/foundation/README.md#bootstrap-runbook for the exact commands
# (default local terraform.tfstate, not a custom -state= path -- an
# earlier draft here referenced -state=bootstrap.local.tfstate, corrected
# once `tofu init -help` confirmed init has no -state flag, so
# -migrate-state could only ever find state at the default path). Once
# that bootstrap has run, oci/eu-madrid-1/lab/00-foundation/terragrunt.hcl
# includes this root.hcl normally -- the bucket already exists by the
# time that unit is ever touched.
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
# LOCKING NOTE (resolved, PR B): `use_lockfile` was left enabled after PR A
# pending verification. Now checked against OCI's own S3 Compatibility API
# reference (docs.oracle.com/en-us/iaas/Content/Object/Tasks/
# s3compatibleapi_topic-Amazon_S3_Compatibility_API_Support.htm), which
# explicitly enumerates supported PutObject request headers — only
# encryption (x-amz-server-side-encryption-*) and chunked-upload
# (Content-Encoding: aws-chunked, x-amz-decoded-content-length) headers are
# listed. If-None-Match/If-Match are conspicuously absent, unlike AWS S3's
# own PutObject reference, which documents them explicitly. Absence from
# an otherwise-detailed reference is real (if not 100%-conclusive)
# evidence against support, not proof of absence — but per this program's
# "do not assume AWS S3 behavior" rule, that's enough to not enable a
# safety mechanism that could silently fail to serialize writes.
#
# [Cause] -> OCI's official S3-Compatibility API docs do not list
#   If-None-Match/If-Match among supported PutObject headers.
# [Impact] -> use_lockfile's native locking depends on conditional writes
#   via If-None-Match; if OCI silently ignores or errors on that header,
#   concurrent `terragrunt apply` runs could race and corrupt or overwrite
#   state without any lock error ever surfacing.
# [Remediation] -> use_lockfile left DISABLED below. This repo's actual
#   concurrency control is process-level: never run `terragrunt apply`
#   concurrently against the same unit (single-maintainer repo; CI never
#   auto-applies — see infrastructure/README.md#apply-gate). Revisit if
#   Oracle documents conditional-write support, or if this is empirically
#   confirmed against a real OCI tenancy (a 412 on a repeated
#   If-None-Match: * PUT would confirm it; a silent 200 would confirm the
#   header is ignored).

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
    use_lockfile                = false # see LOCKING NOTE above — not enabled without verified conditional-write support
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
