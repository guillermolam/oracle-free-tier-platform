# SPEC-COMP-001 — Compute & Talos Node Foundation

**Status:** Ready
**Initiative:** I04 Compute & Talos Foundation
**Epic:** EPIC-COMP-01

## Context

M1 delivered the network foundation (`SPEC-NET-001..006`): a VCN with four
trust zones, an attached-but-inert DRG (ADR-0009), and route tables whose
private-zone egress rule resolves to `null` until a software-NAT target
exists (the Always Free tenancy has `nat-gateway-count = 0` and a per-VCN
Service Gateway limit of 0 — SPIKE-NET-01). `docs/arch/cloud-deployment.mmd`
and ADR-0002 already decide that Kubernetes nodes run Talos Linux. This
Spec creates the compute foundation those nodes — and the software-NAT
instance — live on. It resolves SPIKE-COMP-01 (Ampere A1 shape split).

## Problem Statement

No compute instances exist. Three downstream needs are blocked on the same
foundation: (1) private-zone egress needs a software-NAT instance
(`micro-nat`) because managed NAT/SGW are quota-zero; (2) the Kubernetes
control plane and workers need Talos nodes in the Management and Workload
zones; (3) every platform subsystem (Cilium, Flux, OpenBao, …) needs a
cluster to land on. The Always Free envelope (4 Ampere A1 OCPU / 24 GB RAM
ARM + 2 AMD E2.1.Micro x86 + 200 GB block volume) is small enough that the
shape split is itself a binding decision, not an implementation detail.

## Goals

- A software-NAT instance (`micro-nat`) exists in the Edge zone, tagged for
  `10-network`'s discovery (`data.tf`), forwarding-authorized.
- Talos control-plane and worker nodes exist in the Management and Workload
  zones respectively, no public IP, API-managed only.
- The 4 OCPU / 24 GB ARM budget is allocated explicitly and verifiably.
- A known-good Talos custom image is imported and pinned (BYOI — OCI has no
  official Talos image).

## Non-Goals

- Kubernetes bootstrap itself (`talosctl bootstrap`, cluster formation) —
  that is I05 (`SPEC-K8S-*`). This Spec provisions verified-booting nodes,
  not a running cluster.
- Cilium, SPIRE, Flux, and every platform subsystem (I07+).
- The OpenZiti public/private routers (I08) — they may share the Edge
  zone's compute envelope later, decided there, not here.
- Autoscaling, instance pools, or multi-AD HA — single-AD, fixed-size MVP.

## Requirements

- **REQ-COMP-001** The platform MUST run the software-NAT instance
  (`micro-nat`) on the `VM.Standard.E2.1.Micro` (x86_64) shape, NOT on an
  A1.Flex — NAT forwarding is negligible CPU/RAM, and placing it on the
  free x86 AMD Micro shape keeps the entire 4 OCPU / 24 GB ARM budget for
  the Kubernetes nodes. (Resolves the allocation half of SPIKE-COMP-01.)
- **REQ-COMP-002** The platform MUST allocate the ARM budget as exactly:
  1 control-plane node at 2 OCPU / 12 GB, and 2 worker nodes at
  1 OCPU / 6 GB each — total 4 OCPU / 24 GB, the full Always Free A1
  envelope. The split MUST be expressed as data (a node map), not
  hardcoded per-resource, so a single edit rebases it.
- **REQ-COMP-003** Every Talos node MUST use the pinned,
  verified-to-boot-on-OCI Talos custom image (BYOI import; see
  Constraints). The image OCID MUST be resolved via a tagged/name-keyed
  lookup, never a hardcoded tenancy-specific OCID in the module.
- **REQ-COMP-004** `micro-nat` MUST be placed in the Edge zone with a
  public IP (it terminates forwarded private-zone traffic to the internet)
  and MUST set `skip_source_dest_check = true` on its VNIC — without it,
  OCI drops the forwarded packets regardless of host firewall state.
- **REQ-COMP-005** Talos control-plane nodes MUST be placed in the
  Management zone and workers in the Workload zone; neither MAY have a
  public IP (enforced by REQ-NET-003's `prohibit-public-ip-on-vnic`, which
  this Spec relies on rather than re-implements).
- **REQ-COMP-006** No node — `micro-nat` included — MAY expose SSH or any
  inbound management path from the internet. Talos nodes are API-managed
  via `talosctl` over the Ziti fabric only (ADR-0002/ADR-0003);
  `micro-nat` is reachable only through the Ziti fabric as well.
- **REQ-COMP-007** Node secrets (Talos machine config, Ziti enrollment
  tokens) MUST NOT be placed in instance `metadata.user_data` — OCI's
  `user_data` is not write-only and would land in state and console-readable
  metadata. Nodes MUST boot in maintenance/no-secret mode and receive
  configuration via `talosctl apply-config` (Talos) over the fabric, per
  the platform's secrets strategy (I11 owns the backing store).
- **REQ-COMP-008** `micro-nat` MUST carry freeform tag
  `role = "software-nat"` — the exact tag `10-network`'s
  `data.oci_core_instances.software_nat` discovery matches on
  (`infrastructure/modules/network/data.tf`). This tag is the contract
  between the two units; changing it on either side is a breaking change.
- **REQ-COMP-009** `micro-nat`'s VNIC MUST be authorized to receive the
  forwarded Management/Workload/Data traffic (the Edge-zone ingress
  authorization for those CIDRs, via NSG per SPEC-NET-004) and to forward
  it onward. The route pinned by `10-network` stays "routable but not
  authorized" until this exists — see that module's Route-matrix note.
- **REQ-COMP-010** Every node MUST boot and stay bootable on OCI before any
  cluster work begins: the Talos image MUST be a version with a verified
  OCI boot (see Constraints — the BYOI boot regression), proven by the
  node reaching Talos maintenance mode / `talosctl` reachability, not by
  instance state `RUNNING` alone.

## Constraints

- **Always Free envelope (hard):** 4 A1 OCPU / 24 GB RAM (ARM) + 2 AMD
  E2.1.Micro (x86) + 200 GB block volume total. Boot volumes: 4 nodes ×
  50 GB (OCI minimum) = 200 GB — exactly at budget; no headroom for
  additional boot volumes without revisiting this Spec.
- **Single AD:** eu-madrid-1 exposes one availability domain
  (`SCLl:EU-MADRID-1-AD-1`) — no AD-level distribution is possible.
- **Talos on OCI is BYOI and Tier-3** (no Sidero automated OCI testing):
  a known recent boot regression (qcow2 cluster-size / firmware metadata)
  means "latest Talos factory image" is NOT safe to assume bootable. The
  pinned image MUST be one verified to boot on `VM.Standard.A1.Flex`
  (PARAVIRTUALIZED, UEFI_64) — verification is part of this Spec's
  acceptance, not an afterthought.
- **Ampere capacity is contended** on Always Free — A1 instance creation
  can return out-of-capacity for extended periods. This is a retry/queue
  reality, not a code defect; the Spec's verification tolerates it.
- Module lives under `infrastructure/modules/compute`; state unit
  `30-compute` (ADR-0007's coarse-grained boundary — compute is one blast
  radius), depending on `00-foundation` and `10-network`.

## Interfaces

**Input:** `compartment_ocid` (from `00-foundation`); `subnet_ids{edge,
management,workload}`, `route_table_ids`, NSG OCIDs (from `10-network`);
Talos image reference (custom image imported by this Spec's pipeline).
**Output:** `micro_nat_private_ip_ocid` (the value `10-network`'s
`nat_egress_target_ocid`/tag-discovery resolves to), node instance OCIDs
and private IPs keyed by role, per-node Talos endpoints. Consumed by:
`10-network` (egress route target, via tag discovery — no cross-unit
state dependency), I05 (cluster bootstrap), I08 (Ziti router placement).

## Dependencies

`SPEC-OCI-001` (compartment/IAM), `SPEC-NET-001..004` (subnets, route
tables, NSG authorization, the `role = "software-nat"` discovery contract
and the "routable but not authorized" interim state this Spec closes).
Blocks I05 (Kubernetes bootstrap), I06 (container runtime — SPIKE-RT-01),
I08 (ZTNA).

## Security Requirements

REQ-COMP-004/006/007 are the binding controls: the only public compute
VNIC is `micro-nat`'s, and it is a forwarding appliance with no workload
and no inbound management from the internet; every management path is
Ziti-fabric-only (no SSH anywhere); no node secret ever transits OCI
metadata. The control plane in Management with no public IP keeps
`kube-apiserver` off any direct internet path (ADR-0003).

## Failure Modes

- **A1 out-of-capacity** on apply → retry; not a defect. The apply is
  idempotent — a partially-created node set is retried cleanly.
- **Talos image fails to boot** (BYOI regression) → caught by
  REQ-COMP-010's maintenance-mode verification before I05 touches the
  node; the fix is a known-good pinned image, never a blind version bump.
- **`micro-nat` forwarding silently broken** (forgot
  `skip_source_dest_check`) → caught by `tofu test` asserting the flag
  plus a live egress probe post-I05, not by instance state.
- **Secret in `user_data`** → prevented by REQ-COMP-007's
  maintenance-mode-only boot; a review/CI check asserts no `user_data`
  carries machine-config or token material.

## Observability Requirements

`tofu plan` output attached to PR (plan.yml). Post-apply, node
reachability via `talosctl` (maintenance mode) is the readiness signal;
runtime observability lands with I16, not here.

## Acceptance Criteria

```text
Given the compute module is applied in the lab environment
When `tofu apply` completes
Then a micro-nat instance exists in the Edge zone tagged
  role = "software-nat" with skip_source_dest_check = true and a public IP
And one Talos control-plane node (2 OCPU/12 GB) exists in Management and
  two Talos workers (1 OCPU/6 GB each) exist in Workload, none with a
  public IP
And every Talos node reaches Talos maintenance mode / is talosctl-reachable
And 10-network's next apply adds the Management/Workload/Data 0.0.0.0/0
  route targeting micro-nat (tag discovery resolves non-empty)
And no instance's metadata.user_data contains machine-config or token
  material
```

## Verification

```bash
tofu validate
tofu test  # infrastructure/modules/compute/*.tftest.hcl
oci compute instance list --compartment-id "$C" \
  --query "data[*].{name:\"display-name\", shape:shape, state:\"lifecycle-state\"}"
oci compute instance get --instance-id "$MICRONAT" \
  --query "data.{skip:\"skip-source-dest-check\"}"  # via its VNIC
talosctl --nodes "$NODE_IP" version  # maintenance-mode reachability
```

## Documentation Impact

`docs/01-architecture/compute.md` (new) — shape-split table, zone-to-node
map, the BYOI image pipeline, and the micro-nat forwarding contract.

## Diagram Impact

Architecture Impact: `ARCH-COMP-MICRO-NAT`, `ARCH-COMP-NODE` (new concept
IDs — added to `traceability.md` by this Spec), `ARCH-ZONE-EDGE`,
`ARCH-ZONE-MGMT`, `ARCH-ZONE-WORKLOAD`, `ARCH-FLOW-EGRESS`.
Diagram: `docs/arch/cloud-deployment.mmd`.

## ADR Impact

[ADR-0002](../02-decisions/ADR-0002-talos-node-os.md) (Talos node OS — this
Spec is its first implementation; the pinned Talos version it mandates is
recorded here). Resolves SPIKE-COMP-01 (shape split) — recorded as the
Decision Artifact in this Spec's Requirements.

## Threat Model Impact

Introduces the first compute assets (a public-VNIC forwarding appliance and
the Talos node set) into EPIC-TM-01's inventory — the Edge-zone public IP
and the no-SSH / no-secrets-in-metadata controls are the new boundary
statements.

## Operational Impact

`micro-nat` and the Talos nodes become day-2 objects (patch, reboot,
replace) under I24. Talos upgrades are a `talosctl` operation (I24
runbook), not an in-place edit (ADR-0002). A1 capacity contention may force
a scheduled retry window for node replacement.

## Rollback / Recovery

Safe to `tofu destroy` pre-I05 (no cluster state exists on the nodes yet).
After bootstrap, node replacement is a Talos member-replace operation, not
a console edit. The custom image and the `role = "software-nat"` tag
contract are rollback-safe (deleting an instance does not break
`10-network` — its route reverts to the documented `null` interim state).

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
