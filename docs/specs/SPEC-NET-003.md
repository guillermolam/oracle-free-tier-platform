# SPEC-NET-003 — Trust-Zone Route Tables

**Status:** Ready
**Initiative:** I03 Network & Trust-Zone Foundation
**Epic:** EPIC-NET-03

## Context

`docs/arch/cloud-deployment.mmd` shows one route table per trust zone
(Edge, Management, Workload, Data route tables), each with distinct traffic
rules matching that zone's role in the RED/GREEN/BLUE/PURPLE/ORANGE flow
model the diagram documents.

## Problem Statement

`SPEC-NET-001` creates subnets and `SPEC-NET-002` creates gateways, but
nothing yet routes traffic between them. Without zone-specific route
tables, subnets fall back to the VCN default route table, which cannot
express "Edge routes to IGW, everything else routes to NAT" simultaneously.

## Goals

- Each trust-zone subnet has its own route table — no subnet uses the VCN
  default.
- Edge routes internet-bound traffic to the Internet Gateway.
- Management/Workload/Data route internet-bound traffic to the NAT Gateway
  only.
- All zones route OCI-service traffic to the Service Gateway.

## Non-Goals

- Security Lists / NSGs (`SPEC-NET-004`).
- Activating the DRG route slot (I21).

## Requirements

- **REQ-NET-011** The platform MUST create four route tables (Edge,
  Management, Workload, Data), each associated with exactly one subnet
  from `SPEC-NET-001`.
- **REQ-NET-012** The Edge route table MUST route `0.0.0.0/0` to the
  Internet Gateway (`SPEC-NET-002`).
- **REQ-NET-013** The Management, Workload, and Data route tables MUST
  route `0.0.0.0/0` to the NAT Gateway, and MUST NOT route to the Internet
  Gateway under any rule.
- **REQ-NET-014** All four route tables MUST route the OCI Services Network
  CIDR label to the Service Gateway.
- **REQ-NET-015** The Management route table MAY reserve a route rule slot
  for future on-prem/other-cloud CIDRs via the DRG once I21 activates it;
  this Spec leaves that slot unpopulated.

## Constraints

Module lives under `infrastructure/modules/network`, consuming
`SPEC-NET-001` and `SPEC-NET-002` outputs; no new OCI resource types beyond
`oci_core_route_table` and `oci_core_route_table_attachment`.

## Interfaces

**Input:** `vcn_id`, `subnet_ids` (from `SPEC-NET-001`), `igw_id`, `nat_id`,
`sgw_id` (from `SPEC-NET-002`). **Output:** `route_table_ids{edge,
management,workload,data}`. Consumed by I04 (compute subnet attachment).

## Dependencies

`SPEC-NET-001`, `SPEC-NET-002`. Blocks I04 (compute cannot safely attach to
a subnet with no route table).

## Security Requirements

REQ-NET-013 is the binding control: this Spec's acceptance criteria must
positively assert the *absence* of an Internet Gateway route on
Management/Workload/Data, not merely the presence of a NAT route — a subnet
with both would still leak a public path.

## Failure Modes

A future PR adds an Internet Gateway route to a private-zone table by
mistake → this Spec's `tofu test` coverage must fail the plan, not just the
apply, so it's caught in CI before merge.

## Observability Requirements

`tofu plan` output attached to PR. No runtime signal — no running
component.

## Acceptance Criteria

```
Given the route-tables module is applied in the lab environment
When `tofu apply` completes
Then the Edge route table's only 0.0.0.0/0 rule targets the Internet Gateway
And the Management, Workload, and Data route tables' only 0.0.0.0/0 rule
  targets the NAT Gateway
And no route table other than Edge references the Internet Gateway
And all four route tables include a rule targeting the Service Gateway for
  the OCI Services Network CIDR label
```

## Verification

```
tofu validate
tofu test  # infrastructure/modules/network/*.tftest.hcl
oci network route-table list --compartment-id $C --vcn-id $VCN
```

## Documentation Impact

`docs/01-architecture/network.md` — route table section (extends
`SPEC-NET-001`/`SPEC-NET-002`'s entries).

## Diagram Impact

None beyond the existing `docs/arch/cloud-deployment.mmd`, which already
depicts this exact route-table-per-zone model.

## ADR Impact

None beyond [ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md).

## Threat Model Impact

Route tables are the mechanism that makes the "no public path off Edge"
trust boundary real, not just a NSG intention — feeds EPIC-TM-01 directly
and is a primary control the threat model will cite.

## Operational Impact

None day-2 beyond standard `tofu` drift detection (I23) — a manually added
route via console would be exactly the kind of drift that detection exists
to catch.

## Rollback / Recovery

Safe to `tofu destroy` before I04 attaches compute to these route tables.
After that, rollback is a new PR, never a manual console edit.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
