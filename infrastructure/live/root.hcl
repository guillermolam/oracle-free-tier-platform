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
# file.
#
# [Cause] -> this block previously set access_key/secret_key = get_env(...)
#   directly. OpenTofu's own S3 backend docs are explicit that any
#   credential set as a literal backend argument -- even one sourced from
#   an env var at generate-time -- gets written to disk in the generated
#   backend.tf AND in .terraform's own tracking files, both inside every
#   Terragrunt working directory (verified: a real Customer Secret Key
#   was found sitting in a stale, gitignored-but-real
#   .terragrunt-cache/.../backend.tf during this repo's real bootstrap
#   operations).
# [Impact] -> every `terragrunt init`/`plan`/`apply` left a plaintext copy
#   of the S3-compat secret on local disk, outside git (gitignored,
#   confirmed never staged) but still real credential material at rest
#   longer than necessary, and easy to forget to clean up.
# [Remediation] -> access_key/secret_key removed entirely below.
#   OpenTofu's S3 backend already falls back to the standard AWS SDK
#   credential chain (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY read
#   directly from the process environment at request time) when neither
#   is set in the backend config -- confirmed via OpenTofu's own docs,
#   which recommend exactly this ("keep authentication settings in the
#   standard AWS CLI configuration/environment... instead of using the s3
#   backend arguments directly"). The env var names are unchanged and
#   still required at apply/plan time -- they simply never get rendered
#   into any file on disk now.
#
# CREDENTIAL SCOPE NOTE: despite the AWS-shaped variable names below, this
# is NOT AWS. It is OCI Object Storage's Amazon S3 Compatibility API,
# authenticated with an OCI Customer Secret Key. The s3 backend is simply
# an S3-protocol client, so it borrows the AWS SDK's env var names
# (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) as its credential interface
# -- those values must always be the OCI Customer Secret Key pair
# (`platform-tfstate-backend`), never real AWS account credentials.
#
# [Cause] -> the AWS SDK credential chain this backend relies on does not
#   stop at environment variables -- if they're unset, it silently walks
#   on to ~/.aws/credentials, ~/.aws/config (including cached AWS SSO
#   sessions), then EC2/ECS metadata. Confirmed empirically: a real
#   `terragrunt init` in an environment with no OCI_* env vars set but an
#   unrelated AWS SSO profile present in ~/.aws/credentials fell through
#   to that profile and failed on an expired SSO token, rather than
#   failing on "no OCI credentials" -- the honest, correct error.
# [Impact] -> an unrelated AWS account (or a stale/expired one) could
#   silently satisfy this backend's credential check, masking the real
#   problem (OCI Customer Secret Key not supplied) with a confusing,
#   unrelated AWS error -- or worse, could succeed against the wrong
#   target if such a profile ever pointed at a real AWS S3 bucket sharing
#   this key/bucket naming.
# [Remediation] -> shared_credentials_files/shared_config_files below are
#   pointed at a guaranteed-nonexistent path, per OpenTofu's own S3
#   backend docs (which default these to ~/.aws/credentials /
#   ~/.aws/config respectively). NOTE (verified, not assumed): setting
#   these to an empty list (`[]`) does NOT work -- tested empirically,
#   OpenTofu's S3 backend treats an empty list as "unset" and silently
#   re-applies its own default paths, so the SSO fallback still fired.
#   Only a nonexistent-but-non-empty path list actually suppresses that
#   layer of the credential chain (confirmed: the next real init attempt
#   correctly skipped straight past ~/.aws entirely to the EC2 IMDS
#   layer, which skip_metadata_api_check then correctly blocks).
#   Combined with skip_metadata_api_check already set and access_key/
#   secret_key deliberately left unset, the only remaining credential
#   source is AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY read from the
#   process environment -- the backend now fails closed with a clear
#   "no valid credential sources found" error instead of silently
#   borrowing an unrelated AWS profile.
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

    # access_key/secret_key deliberately NOT set here -- see CREDENTIAL
    # NOTE above. AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY must still be
    # exported in the shell running terragrunt/tofu (or supplied by
    # infrastructure/live/scripts/tg -- see CREDENTIAL SCOPE NOTE above); the
    # S3 backend picks them up from the process environment automatically.
    use_path_style              = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = false # see LOCKING NOTE above — not enabled without verified conditional-write support

    # See CREDENTIAL SCOPE NOTE above: forces the AWS SDK credential
    # chain to stop at environment variables instead of silently falling
    # through to a local AWS profile or cached SSO session.
    shared_credentials_files = ["/dev/null/does-not-exist"]
    shared_config_files      = ["/dev/null/does-not-exist"]
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
