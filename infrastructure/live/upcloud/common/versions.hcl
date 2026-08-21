# Provider version pins for UpCloud infrastructure composition
#
# OpenTofu version requirement is identical across OCI and UpCloud to maintain
# a consistent IaC toolchain across both providers; see
# infrastructure/live/common/versions.hcl (included by oci/*/env.hcl) for the
# baseline. UpCloud provider is pinned to match the module's versions.tf.

locals {
  terraform_version = ">= 1.12.0"
  upcloud_version   = "5.34.0"
}
