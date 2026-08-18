# Shared version floor. Verified against authoritative upstream sources —
# see ../../README.md#toolchain-verified-against-authoritative-sources-not-memory
# — not copied from memory. Each module's own versions.tf still declares
# its own required_providers block; this file exists so every live/ unit
# can assert a consistent floor, not to replace that declaration.

locals {
  opentofu_version_constraint = ">= 1.12.0"
  oci_provider_version        = "8.27.0" # oracle/terraform-provider-oci, verified 2026-08-18
}
