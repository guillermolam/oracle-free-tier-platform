# `compute` module

## Purpose

Implements `SPEC-COMP-001` (REQ-COMP-001..010, Compute & Talos Node Foundation):
the software-NAT instance (`micro-nat`) and the Talos control-plane + worker
nodes on A1.Flex ARM64 within the Always Free envelope (4 OCPU / 24 GB). This
is the third module in the state DAG — `00-foundation`, `10-network`,
`30-compute`.

## Input contract

| Variable | Required | Description |
| --- | --- | --- |
| `compartment_ocid` | yes | OCI compartment OCID from `00-foundation`. |
| `environment` | yes | One of `lab`, `staging`, `prod`. |
| `platform_name` | no (default `"oracle-free-tier-platform"`) | Used for resource `display_name` tagging. |
| `subnet_ids` | yes | Map keyed by zone (`edge`, `management`, `workload`, `data`) from `10-network`. |
| `nsg_ids` | no (default `{}`) | NSG OCIDs keyed by purpose (`ziti`, `ingress`, `control`, `worker`, `storage`) from `SPEC-NET-004`. |
| `micro_nat_shape` | no (default `VM.Standard.E2.1.Micro`) | Fixed to E2.1.Micro per REQ-COMP-001; cannot be changed without re‑reviewing SPIKE-COMP-01. |
| `talos_version` | no (default `v1.9.4`) | Pinned Talos Linux version; must be verified‑to‑boot on A1.Flex ARM64 (paravirtualized UEFI_64). |
| `talos_cpu_cores` | no (default `4`) | Must equal 4 (Always Free ARM envelope). |
| `talos_memory_gbs` | no (default `24`) | Must equal 24 GB (Always Free ARM envelope). |

Output contract

| Output | Consumed by |
| --- | --- |
| `micro_nat_private_ip_ocid` | `10-network` – resolves egress route target via tag discovery. |
| `node_ocids_by_role` | `I05` (K8s bootstrap) – knows which instance is CP vs worker. |
| `node_private_ips_by_role` | `I05` / `I08` – talosctl endpoints. |
| `talos_endpoints` | `I05` – formatted for `talosctl` URLs. |
| `talos_image_ocid` | downstream modules needing the custom image OCID. |

## Software‑NAT discovery

The Always Free account has `nat-gateway-count = 0` (SPIKE-NET-01). This module
therefore creates a `micro-nat` instance tagged `role = "software-nat"`. The
`10-network` module discovers it at plan time by:

```
data.oci_core_instances.software_nat
  -> filter by freeform_tags."role" == "software-nat"
data.oci_core_private_ips.software_nat
  -> resolve that instance's primary private IP
```

No Terragrunt dependency exists between `10-network` and `30-compute`; the
order of apply is: first `10-network` (no egress route), then `30-compute`
(micro‑nat created and tagged), then a second `10-network` apply (route appears).

## Talos node placement

- Control‑plane → Management zone, shape `VM.Standard.A1.Flex`, 2 OCPU / 12 GB.
- Two workers → Workload zone, same shape, 1 OCPU / 6 GB each.
- Total ARM envelope = 4 OCPU / 24 GB (REQ-COMP-002). No Talos node may have
  a public IP (REQ-COMP-005). Boot occurs in maintenance mode; machine config
  and tokens are later applied via `talosctl apply-config` over the Ziti fabric
  (REQ-COMP-007). No SSH keys or secrets are placed in `metadata.user_data`
  (REQ-COMP-006/007).

## Testing

Run the module's test suite against a sandbox tenancy:

```sh
cd infrastructure/modules/compute
tofu init -backend=false -input=false
tofu validate
tofu test  # runs compute_positive.tftest.hcl and compute_negative.tftest.hcl
```

## Example

Minimal usage in a Terragrunt live unit (see `examples/minimal/main.tf`):

```hcl
compute = {
  source = "git::@src//infrastructure/modules/compute?ref=main"
  compartment_ocid = data.oci_identity.compartment.OCID
  environment = "lab"
  subnet_ids = {
    edge       = data.oci_core_subnet.edge.id
    management = data.oci_core_subnet.management.id
    workload   = data.oci_core_subnet.workload.id
    data       = data.oci_core_subnet.data.id
  }
}
```

## Validation

```sh
tofu fmt -check
tofu init -backend=false -input=false
tofu validate
tofu test
```
