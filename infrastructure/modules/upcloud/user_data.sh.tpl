#!/bin/bash
# Cloud-init user-data script for k0s Kubernetes cluster initialization
# This script will be executed as the root user

set -Eeuo pipefail

# Platform bootstrap script will be embedded here
# Variables injected via cloud-init:
# - ADMIN_USER: Administrative user account name
# - ADMIN_SSH_KEY: Public SSH key for admin user
# - BOOTSTRAP_SSH_CIDR: CIDR block allowed for bootstrap SSH access
# - SSH_PORT: SSH port number (default: 22)

# Source the platform init script via cloud-init or URL
# This is a placeholder; the actual implementation will use templatefile()
# to embed the init.sh content from scripts/upcloud/vm-linux/

# For now, log that we're in the bootstrap script
echo "k0s cloud-init bootstrap starting..." >> /var/log/cloud-init-custom.log
