# Defined-tags contract. See ../../README.md#tagging-contract for the
# full dimension list and which dimensions are deferred pending
# governance decisions this repo hasn't made yet — do not add tags here
# that require an undecided policy (owner, DR tier, criticality, ...).

locals {
  platform_tags = {
    "Platform.System"    = "oracle-free-tier-platform"
    "Platform.ManagedBy" = "opentofu"
  }
}
