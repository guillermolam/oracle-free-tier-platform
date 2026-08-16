# SPEC-NET-001 — OCI VCN and Trust-Zone Subnet Foundation

**Status:** Ready
**Initiative:** I03 Network & Trust-Zone Foundation
**Epic:** EPIC-NET-01

## Context

[`docs/arch/cloud-deployment.mmd`](../arch/cloud-deployment.mmd) and
[ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md)
already define the target shape: one VCN, four trust-zone subnets. This
Spec turns that diagram into the first OpenTofu module.

## Problem Statement

No OCI network resources exist. Every downstream initiative (compute, ZTNA,
Kubernetes bootstrap) needs a VCN and trust-zone subnets to attach to.

## Goals

- A single VCN exists with deterministic CIDR allocation.
- Four subnets exist, each mapped to exactly one trust zone.
- Subnet-to-zone mapping is enforced by module contract, not convention.

## Non-Goals

- Gateways, route tables, NSGs (`SPEC-NET-002` through `SPEC-NET-004`).
- Compute attachment (I04).

## Requirements

- **REQ-NET-001** The platform MUST create exactly one OCI VCN using CIDR
  `10.10.0.0/16`.
- **REQ-NET-002** The platform MUST create four subnets: Edge
  (`10.10.10.0/24`), Management (`10.10.20.0/24`), Workload
  (`10.10.30.0/24`), Data (`10.10.40.0/24`).
- **REQ-NET-003** Management, Workload, and Data subnets MUST NOT allow
  public IP assignment (`prohibit-public-ip-on-vnic = true`).
- **REQ-NET-004** Only the Edge subnet MAY allow public IP assignment, and
  only for the ingress and OpenZiti edge-router VNICs (`SPEC-NET-004`
  scope).
- **REQ-NET-005** The module MUST expose subnet OCIDs as outputs keyed by
  zone name, for consumption by `SPEC-NET-002` (gateways) and I04
  (compute).

## Constraints

OCI Free Tier (no cost-bearing network resources); ARM64 downstream
consumers; ranges MUST NOT overlap `10.10.0.0/16` to leave room for I21
DRG-based hybrid peering later; module lives under
`infrastructure/modules/network`.

## Interfaces

**Input:** `compartment_ocid` (from `SPEC-OCI-001`), `region`. **Output:**
`vcn_id`, `subnet_ids{edge,management,workload,data}`. Consumed by:
`infrastructure/compositions/network`, and transitively
`infrastructure/live/oci/eu-madrid-1/lab`.

## Dependencies

`SPEC-OCI-001` (compartment/IAM) — must exist first. Blocks `SPEC-NET-002`
(gateways), `SPEC-NET-003` (routing), `SPEC-NET-004` (security lists/NSGs).

## Security Requirements

No public IP on Management/Workload/Data by construction (REQ-NET-003) —
enforced in the module, not left to composition-time discipline.

## Failure Modes

CIDR collision with a future DRG peer → module `fmt`/`validate` catches
literal duplication; peering-time collision is out of scope for this Spec
and owned by I21. Partial apply leaving an orphaned VCN → `tofu` state is
the source of truth; no manual console changes permitted (`SECURITY.md`).

## Observability Requirements

`tofu plan` output attached to PR (already enforced by `plan.yml`). No
runtime signal — this Spec has no running component.

## Acceptance Criteria

```text
Given the network module is applied in the lab environment
When `tofu apply` completes
Then exactly one VCN with CIDR 10.10.0.0/16 exists
And four subnets exist with the CIDRs in REQ-NET-002
And `oci network subnet get` reports prohibit-public-ip-on-vnic=true for
  Management, Workload, and Data
```

## Verification

```bash
tofu validate
tofu test  # infrastructure/modules/network/*.tftest.hcl
oci network vcn list --compartment-id $C \
  --query "data[?\"cidr-block\"=='10.10.0.0/16']"
```

## Documentation Impact

`docs/01-architecture/network.md` (new) — CIDR table, zone-to-subnet map.

## Diagram Impact

None beyond the existing `docs/arch/cloud-deployment.mmd`, which this Spec
implements as-is.

## ADR Impact

[ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md)
(records the four-zone model already implicit in the diagram).

## Threat Model Impact

Establishes the network trust boundaries threat-modeling depends on — feeds
EPIC-TM-01 (I20) directly.

## Operational Impact

None day-2 beyond standard `tofu` drift detection (I23).

## Rollback / Recovery

`tofu destroy` on the module is safe pre-attachment (nothing depends on it
yet); once compute/gateways attach, rollback is a new PR reverting the
module version, never a manual console edit.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
