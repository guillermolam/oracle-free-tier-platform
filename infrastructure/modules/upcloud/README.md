# UpCloud Module

A Terraform module for provisioning Kubernetes cluster infrastructure on UpCloud.

## Overview

This module consolidates UpCloud network, router, storage, server, and firewall resources into a reusable,
parameterized package. It creates a single Kubernetes node with hardened security defaults and cloud-init
support for bootstrap provisioning.

## Resources Created

- **Router**: UpCloud managed router for network routing
- **Network**: Private network with DHCP and gateway configuration
- **Storage**: Root disk volume (parameterizable size and tier)
- **Server**: Compute instance with public and private network interfaces
- **Firewall Rules**: Inbound/outbound traffic policies (default-deny, explicit allow)

## Module Contract

### Required Inputs

None — all inputs have sensible defaults.

### Optional Inputs

| Input | Type | Default | Description |
| ------- | ------ | --------- | ------------- |
| `zone` | string | `es-mad1` | UpCloud availability zone |
| `plan` | string | `DEV-2xCPU-4GB` | Server plan/SKU |
| `disk_size` | number | `60` | Root disk size in GB (10–4096) |
| `tags` | map(string) | See below | Resource tags |
| `hostname` | string | `k8s-node` | Server hostname |
| `admin_user` | string | `ubuntu` | Admin account name |
| `admin_ssh_key` | string | `""` | Public SSH key (sensitive) |
| `bootstrap_cidr` | string | `""` | Bootstrap SSH CIDR block |
| `ssh_port` | number | `22` | SSH port (1–65535) |
| `network_name` | string | `k8s-cluster-network` | Network name |
| `network_cidr` | string | `10.0.0.0/24` | Network CIDR block |
| `router_name` | string | `k8s-cluster-router` | Router name |
| `storage_tier` | string | `standard` | Storage tier (`standard` or `maxiops`) |
| `metadata_enabled` | bool | `true` | Enable cloud-init metadata |
| `user_data` | string | `""` | Cloud-init user data script |
| `firewall_rules` | object | See below | Inbound/outbound firewall rules |

### Default Tags

```hcl
{
  environment = "lab"
  owner       = "platform"
}
```

### Default Firewall Rules

**Inbound:**

- TCP 22 (SSH)
- TCP 80 (HTTP)
- TCP 443 (HTTPS)
- ICMP Echo Request (ping)

**Outbound:**

- TCP 80 (HTTP)
- TCP 443 (HTTPS)
- UDP 53 (DNS)
- ICMP Echo Reply (ping reply)

**Always Applied:**

- Default deny inbound/outbound (explicit allow only)

### Outputs

| Output | Type | Description |
| -------- | ------ | ------------- |
| `server_id` | string | UpCloud server ID |
| `server_ip_address` | string | Server primary IP address |
| `server_hostname` | string | Server hostname |
| `server_zone` | string | Server availability zone |
| `network_id` | string | Network ID |
| `network_address` | string | Network CIDR block |
| `router_id` | string | Router ID |
| `storage_id` | string | Root disk storage ID |
| `storage_size` | number | Storage size in GB |
| `firewall_rule_ids` | list(string) | Firewall rule IDs |

## Assumptions

1. **UpCloud API Token**: The `UPCLOUD_API_TOKEN` environment variable is set and valid.
2. **Zone Availability**: The specified zone (`var.zone`) exists and is actively accepting new servers.
3. **Debian 13 Image**: A Debian 13 template image exists in the target zone.
4. **Network CIDR**: The network CIDR block (`var.network_cidr`) does not conflict with existing infrastructure.
5. **Metadata Service**: Cloud-init metadata service is available for user-data provisioning.
6. **Storage Tier**: The requested storage tier is available in the target zone.

## Limitations

1. **Single Server Only**: This module creates exactly one server. For multi-node clusters, use multiple
   module instances with distinct hostnames and network interfaces.
2. **Debian 13 Only**: OS image selection is hardcoded to Debian 13. Other Linux distributions are not
   currently supported by this module.
3. **Static Network Configuration**: Network CIDR and gateway are not parameterizable per server; all servers
   in a deployment unit use the same network.
4. **No Load Balancer**: This module does not provision UpCloud load balancers. External traffic distribution
   must be configured separately.
5. **Firewall Rules Are Simple**: Complex, multi-rule firewall policies should be managed separately. This
   module supports basic inbound/outbound allow/deny patterns only.
6. **No Storage Snapshots**: The module does not support storage snapshots or backup scheduling.
7. **Immutable Plan**: Once created, changing `var.plan` triggers server recreation; existing applications
   may be disrupted.

## Security Considerations

- **Firewall Default-Deny**: All traffic is denied by default; rules must explicitly allow traffic.
- **SSH Hardening**: Configure `BOOTSTRAP_SSH_CIDR` to restrict SSH access to known networks during bootstrap;
  remove once Teleport/OpenZiti is validated.
- **Metadata Service**: Metadata service is enabled for cloud-init; ensure cloud-init scripts do not expose secrets.
- **No Root Login**: Admin user configuration assumes password authentication is disabled and SSH key
  authentication is the sole access method.

## Example Usage

```hcl
module "upcloud_node" {
  source = "../../modules/upcloud"

  zone              = "es-mad1"
  plan              = "DEV-2xCPU-4GB"
  disk_size         = 60
  hostname          = "k8s-worker-1"
  admin_user        = "ubuntu"
  admin_ssh_key     = "ssh-ed25519 AAAA... user@host"
  bootstrap_cidr    = "203.0.113.0/24"
  ssh_port          = 22
  network_name      = "k8s-network"
  network_cidr      = "10.0.0.0/24"
  router_name       = "k8s-router"

  tags = {
    environment = "production"
    owner       = "platform-team"
    cluster     = "main"
  }
}
```

## Testing

Tests are located in `tests/` and validate:

1. **Positive Tests** (`compute_positive.tftest.hcl`):
   - Valid configuration produces expected resources
   - Default firewall rules are applied correctly
   - Network and router creation succeeds

2. **Negative Tests** (`compute_negative.tftest.hcl`):
   - Invalid zone is rejected
   - Invalid disk size is rejected
   - Invalid hostname format is rejected
   - Invalid SSH port is rejected

Run tests with:

```bash
cd infrastructure/modules/upcloud
tofu test
```

## Troubleshooting

### Zone Not Available

**Error:** "Zone 'xx-xxxx-x' is not available"

**Solution:** Verify the zone name against `data.upcloud_zones.available` in the UpCloud console, or list
available zones via the UpCloud API.

### No Debian 13 Image Found

**Error:** "No Debian 13 template image found in zone"

**Solution:** The specified zone may not have Debian 13 templates. Check the UpCloud console for available
OS images in that zone.

### API Token Missing

**Error:** "No valid API token found"

**Solution:** Export your UpCloud API token: `export UPCLOUD_API_TOKEN="<token>"`

## Consolidation Notes

This module consolidates:

- `scripts/upcloud/tf-exports/networks.tf` → `main.tf` (upcloud_network, upcloud_router)
- `scripts/upcloud/tf-exports/routers.tf` → Removed (duplicate router definition)
- `scripts/upcloud/tf-exports/servers.tf` → `main.tf` (upcloud_server, upcloud_firewall_rules)
- `scripts/upcloud/tf-exports/storages.tf` → Removed (duplicate storage definition)
- `scripts/upcloud/tf-exports/kubernetes.tf` → External (kept separate for cluster management)

Eliminated duplicates:

- Removed duplicate `upcloud_router` from `routers.tf`
- Removed duplicate `upcloud_storage` from `storages.tf`
- Consolidated all provider and version requirements into `versions.tf`

Parameterized all hardcoded values:

- Zone (`es-mad1` → `var.zone`)
- Server plan (`DEV-2xCPU-4GB` → `var.plan`)
- Server ID/hostname
- Disk size and tier
- Firewall rules (extracted into dynamic blocks)
- Network name, CIDR, router name

Provisioning Logic:

- User-data and post-script logic remains in `scripts/upcloud/vm-linux/` for reference
- Templates (`user_data.sh.tpl`, `post_script.sh.tpl`) are placeholders for cloud-init integration
- Actual provisioning should use `templatefile()` in a Terragrunt live unit to embed init scripts
