# Account-level values shared by every region/environment under this
# repo. No OCIDs, secrets, or Customer Secret Keys here — those come from
# environment variables (local `oci` CLI config / GitHub Actions secrets),
# never committed. See ../../README.md#secrets-and-credentials-strategy.

locals {
  platform_name = "oracle-free-tier-platform"

  # Not itself secret, but account-specific -- sourced from env rather
  # than hardcoded. Every unit gets this via root.hcl's `inputs = merge(...)`
  # without needing to redeclare it.
  tenancy_ocid = get_env("OCI_TENANCY_OCID", "")

  # Object Storage namespace is tenancy-specific but not itself secret;
  # still sourced from env rather than hardcoded, since it's account data,
  # not a portable constant this repo should assume.
  tenancy_namespace = get_env("OCI_OBJECT_STORAGE_NAMESPACE", "")

  # REQ-OCI-005: dedicated, versioned OCI Object Storage bucket for state.
  # Created by 00-foundation's own two-phase bootstrap (REQ-OCI-007) —
  # see ../../README.md#remote-state-bootstrap-sequence. Every other unit
  # references this same bucket once it exists.
  state_bucket_name = "oracle-free-tier-platform-tfstate"
}
