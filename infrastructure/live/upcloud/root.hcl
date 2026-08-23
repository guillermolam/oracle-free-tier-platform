# Root Terragrunt configuration for UpCloud infrastructure.
# Every unit under upcloud/<region>/<env>/ includes this via
# `include "root" { path = find_in_parent_folders() }`.
#
# Unlike OCI (which uses S3 Compatibility API), UpCloud state is stored in
# OCI Object Storage (the same backend as OCI infrastructure) to maintain a
# single state backend for the entire platform. State key paths are prefixed
# by provider to avoid collisions.
#
# CREDENTIAL NOTE: This backend authenticates against OCI Object Storage via
# S3-compatible API, using the same Customer Secret Key as OCI infrastructure.
# The AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY env vars must contain the OCI
# Customer Secret Key (platform-tfstate-backend), not real AWS credentials.
# See infrastructure/live/root.hcl for full credential setup and rationale.

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("common/account.hcl"))
  tags_vars    = read_terragrunt_config(find_in_parent_folders("common/tags.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Use OCI tenancy region for state storage (e.g., eu-madrid-1), not UpCloud zone
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
    key    = "upcloud/${path_relative_to_include()}/terraform.tfstate"
    region = local.region_vars.locals.region

    endpoints = {
      s3 = local.s3_compat_endpoint
    }

    use_path_style              = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = false

    shared_credentials_files = ["/dev/null/does-not-exist"]
    shared_config_files      = ["/dev/null/does-not-exist"]
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "upcloud" {
  # Credentials via UPCLOUD_API_TOKEN environment variable
}
EOF
}

inputs = merge(
  local.account_vars.locals,
  local.tags_vars.locals,
  local.region_vars.locals,
  local.env_vars.locals,
)
