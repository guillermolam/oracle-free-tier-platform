# SPEC-NET-002 — Gateways: IGW / NAT / Service Gateway / DRG

**Status:** Ready
**Initiative:** I03 Network & Trust-Zone Foundation
**Epic:** EPIC-NET-02

## Context

`docs/arch/cloud-deployment.mmd` depicts four gateways at VCN scope: an
Internet Gateway serving the Edge zone, a NAT Gateway for private egress, a
Service Gateway for OCI service access, and a Dynamic Routing Gateway (DRG)
reserved for future hybrid connectivity (I21). This Spec creates all four
gateway objects; route-table wiring is `SPEC-NET-003`.

## Problem Statement

`SPEC-NET-001` creates subnets with no path in or out. Edge ingress, private
egress, and OCI service access (Object Storage, KMS, Logging, Monitoring)
all require dedicated gateways before any route table can reference them.

## Goals

- Internet Gateway exists, reachable only from the Edge route table.
- NAT Gateway exists for Management/Workload/Data egress.
- Service Gateway exists for private OCI service access.
- DRG exists and is attached, inert until I21 activates it — present, not
  omitted, per the platform's "don't silently drop deferred work" rule.

## Non-Goals

- Route table associations (`SPEC-NET-003`).
- DRG peering/tunnel configuration itself (I21 scope) — this Spec only
  creates and attaches the DRG object.

## Requirements

- **REQ-NET-006** The platform MUST create an Internet Gateway attached to
  the VCN, referenced only by the Edge route table (`SPEC-NET-003`).
- **REQ-NET-007** The platform MUST create a NAT Gateway for private egress
  from Management, Workload, and Data subnets.
- **REQ-NET-008** The platform MUST create a Service Gateway providing
  private access to OCI Object Storage, KMS, Logging, and Monitoring
  without traversing the public internet.
- **REQ-NET-009** The platform MUST create a Dynamic Routing Gateway (DRG)
  and attach it to the VCN. OCI requires every DRG attachment to reference
  a DRG route table, so "inert" means that table contains zero route
  rules and has route-table import/propagation disabled — not that the
  attachment itself is absent. It stays empty until I21 begins populating
  it.
- **REQ-NET-010** No gateway other than the Internet Gateway MAY have a
  route enabling inbound internet-originated traffic.

## Constraints

OCI Free Tier (NAT/Service/Internet Gateways carry no direct cost; egress
volume counts against the 10 TB/month Free Tier allowance); module lives
under `infrastructure/modules/network` alongside `SPEC-NET-001`.

## Interfaces

**Input:** `vcn_id` (from `SPEC-NET-001`). **Output:** `igw_id`, `nat_id`,
`sgw_id`, `drg_id`. Consumed by `SPEC-NET-003` (route tables).

## Dependencies

`SPEC-NET-001` (needs `vcn_id`). Blocks `SPEC-NET-003`.

## Security Requirements

REQ-NET-010 is the binding security constraint: only the Internet Gateway
may ever appear as a target for `0.0.0.0/0` inbound. The Service Gateway
uses OCI's Services CIDR label, not `0.0.0.0/0`, by construction.

## Failure Modes

A route table accidentally pointing Management/Workload/Data traffic at the
Internet Gateway instead of NAT → caught by `SPEC-NET-003`'s acceptance
criteria and `tofu test`, not by this Spec directly (this Spec only creates
the gateway objects, not the routes). DRG attached but a route
inadvertently activated before I21 → REQ-NET-009's "no active route rules"
requirement is verified in this Spec's own acceptance criteria.

## Observability Requirements

`tofu plan` output attached to PR. No runtime signal — no running
component.

## Acceptance Criteria

```text
Given the gateways module is applied in the lab environment
When `tofu apply` completes
Then an Internet Gateway, NAT Gateway, and Service Gateway exist attached
  to the VCN from SPEC-NET-001
And a DRG exists and is attached to the VCN via a DRG attachment
And that attachment's DRG route table contains zero route rules
And route-table import/propagation is disabled on that attachment
```

## Verification

```bash
tofu validate
tofu test  # infrastructure/modules/network/*.tftest.hcl
oci network internet-gateway list --compartment-id $C --vcn-id $VCN
oci network drg list --compartment-id $C
oci network drg-route-table-route-rule list --drg-route-table-id "$DRG_RT" \
  --query "length(data)"  # expect 0
```

## Documentation Impact

`docs/01-architecture/network.md` — gateway table (extends the section
`SPEC-NET-001` starts).

## Diagram Impact

None beyond the existing `docs/arch/cloud-deployment.mmd`.

## ADR Impact

None beyond [ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md).

## Threat Model Impact

The Internet Gateway is the platform's sole internet-facing ingress point —
feeds EPIC-TM-01's asset/boundary inventory directly.

## Operational Impact

NAT Gateway egress volume should be watched against the Free Tier's 10
TB/month allowance once workloads exist — tracked as a future
`docs/04-operations/capacity-and-free-tier-envelope.md` entry (I24), not
enforced by this Spec.

## Rollback / Recovery

Safe to `tofu destroy` before any route table references these gateways
(pre-`SPEC-NET-003`). After that, rollback is a new PR, never a manual
console edit.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
