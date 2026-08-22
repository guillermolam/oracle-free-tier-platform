# Environment configuration for lab deployment in eu-madrid-1
#
# This environment hosts UpCloud Kubernetes infrastructure provisioning
# for the oracle-free-tier-platform. State is stored in OCI Object Storage
# (same backend as OCI infrastructure) with a "upcloud/" key prefix.

locals {
  environment    = "lab"
  platform_name  = "oracle-free-tier-platform"
  deployment_tag = "platform-lab"
}
