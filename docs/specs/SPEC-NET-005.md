# SPEC-NET-005 — Traffic-Flow Invariants

**Status:** Ready
**Initiative:** I03 Network & Trust-Zone Foundation
**Epic:** EPIC-NET-05

## Context

`docs/arch/cloud-deployment.mmd`'s traffic-class model (RED/GREEN/BLUE/
PURPLE/ORANGE) is currently expressed only as prose scattered across
`SPEC-NET-001` through `SPEC-NET-004`'s individual requirements — no
single Spec verifies the flows behave as a coherent whole once all of them
are applied together. This Spec is that cross-cutting verification layer.

## Problem Statement

Each Spec can pass its own acceptance criteria while the system as a whole
still permits an unintended path. For example, REQ-NET-013 forbidding an
Internet Gateway route on the Workload route table proves that one wrong
route is absent — it doesn't by itself prove GREEN egress actually reaches
the internet via NAT end-to-end. This Spec defines the seven traffic
classes as first-class, independently verifiable contracts.

## Goals

Every one of the seven flow classes (`ARCH-FLOW-INGRESS`, `-EGRESS`,
`-SERVICE`, `-BACKUP`, `-ADMIN`, `-CONTROL`, `-HYBRID`) has an explicit
source/destination/trust-boundary/route/gateway/security-control/protocol/
allowed-vs-denied/logging/verification definition, checked once
`SPEC-NET-001` through `SPEC-NET-004` and `SPEC-NET-006` are applied.

## Non-Goals

- Implementing any new OCI resource — this Spec provisions nothing (see
  [ADR-0007](../02-decisions/ADR-0007-terragrunt-state-boundaries.md): it
  has no Terragrunt state unit).
- OpenZiti's internal identity/auth behavior (I08) — `ARCH-FLOW-ADMIN`
  here verifies only that the OCI-layer path exists (Edge → Ziti public
  router placement → Management → private router placement).

## Requirements

- **REQ-NET-021** (`ARCH-FLOW-INGRESS`) The platform MUST verify that a
  request from the internet reaches the Edge-zone application ingress via
  the Internet Gateway and Edge route table only, and MUST NOT reach
  Management, Workload, or Data zones directly.
- **REQ-NET-022** (`ARCH-FLOW-EGRESS`) The platform MUST verify that
  outbound traffic from Management/Workload/Data reaches the internet via
  the NAT Gateway only, never via the Internet Gateway.
- **REQ-NET-023** (`ARCH-FLOW-SERVICE`) The platform MUST verify that OCI
  service access (Object Storage, KMS, Logging, Monitoring) from any zone
  routes via the Service Gateway using the OCI Services Network CIDR
  label, never via NAT or the Internet Gateway.
- **REQ-NET-024** (`ARCH-FLOW-BACKUP`) The platform MUST verify that
  Data-zone backup traffic reaches its destination via the Service
  Gateway, under the same constraint as REQ-NET-023.
- **REQ-NET-025** (`ARCH-FLOW-ADMIN`) The platform MUST verify that
  administrative access reaches the Management zone only via the
  Edge-zone Ziti public router and the Management-zone Ziti private
  router — never directly.
- **REQ-NET-026** (`ARCH-FLOW-CONTROL`) The platform MUST verify that
  control-plane traffic (`kube-apiserver` ↔ workers) stays within the
  VCN's private address space and crosses only the `control` and `worker`
  NSGs defined in `SPEC-NET-004`.
- **REQ-NET-027** (`ARCH-FLOW-HYBRID`) The platform MUST verify that, in
  M1, `ARCH-FLOW-HYBRID` carries zero traffic — the DRG route table is
  empty (REQ-NET-009) and no route table references it (REQ-NET-015's
  reserved slot is unpopulated) — confirming
  [ADR-0008](../02-decisions/ADR-0008-drg-reserved-inert-m1.md)'s
  "present but inert" invariant holds.

## Constraints

Verification MUST run only after `SPEC-NET-001` through `SPEC-NET-004`
and `SPEC-NET-006` are all applied — it cannot be verified standalone. No
new OCI resources; test/verification tooling only. Checks are
static/plan-time until I05 exists, at which point a real
network-reachability probe becomes possible.

## Interfaces

**Input:** outputs of `SPEC-NET-001`..`004`, `SPEC-NET-006`
(`subnet_ids`, `route_table_ids`, `nsg_ids`, gateway IDs). **Output:**
none — verification only. Consumed by: I20 (EPIC-TM-01) as its primary
evidence source for the network trust-boundary section of the threat
model.

## Dependencies

`SPEC-NET-001`, `SPEC-NET-002`, `SPEC-NET-003`, `SPEC-NET-004`,
`SPEC-NET-006`.

## Security Requirements

This Spec **is** a security requirement in aggregate form — REQ-NET-021
through REQ-NET-027 are, collectively, the acceptance test suite for
every network-layer security guarantee claimed across `SPEC-NET-001`
through `004`/`006`.

## Failure Modes

A future PR changes one NSG or route table in isolation, passing that
unit's own Spec's acceptance criteria, but breaks a cross-cutting
invariant (e.g., a new NSG rule accidentally opens a second path into
Management) → REQ-NET-021..027's test suite is the only place this class
of regression is caught; individual Specs cannot catch it alone.

## Observability Requirements

Once I16 exists, each flow class SHOULD have a corresponding Hubble/
VCN-flow-log-derived dashboard panel (ties to `SPEC-OCI-003`'s
REQ-OCI-013) — not required by this Spec, noted for I16.

## Acceptance Criteria

```text
Given SPEC-NET-001 through SPEC-NET-004 and SPEC-NET-006 are all applied
  in the lab environment
When the traffic-flow invariant suite runs
Then all seven REQ-NET-021 through REQ-NET-027 assertions pass
And ARCH-FLOW-HYBRID specifically shows zero active routes (REQ-NET-027)
```

## Verification

```bash
tofu test  # cross-module assertions, infrastructure/modules/network/tests/
oci network security-list list --compartment-id "$C" --vcn-id "$VCN"
oci network nsg-rules list --nsg-id "$CONTROL_NSG"
# cross-checked against the seven flow definitions above; scripted rather
# than manual once infrastructure/modules/network exists
```

## Documentation Impact

`docs/01-architecture/network.md` — a dedicated Traffic Flows table
(RED/GREEN/BLUE/PURPLE/ORANGE), completing the doc `SPEC-NET-001`
through `004` already promised.

## Diagram Impact

Architecture Impact: `ARCH-FLOW-INGRESS`, `ARCH-FLOW-EGRESS`,
`ARCH-FLOW-SERVICE`, `ARCH-FLOW-BACKUP`, `ARCH-FLOW-ADMIN`,
`ARCH-FLOW-CONTROL`, `ARCH-FLOW-HYBRID`.
Diagram: `docs/arch/cloud-deployment.mmd` (working-tree draft, not yet
canonicalized — see
[`docs/01-architecture/traceability.md`](../01-architecture/traceability.md)).

## ADR Impact

[ADR-0008](../02-decisions/ADR-0008-drg-reserved-inert-m1.md) — this Spec
is what verifies that ADR's "inert until I21" decision actually holds
(REQ-NET-027). [ADR-0009](../02-decisions/ADR-0009-drg-reuse-and-strip-inert-table.md)
amends the mechanism (reused, stripped auto-created DRG route table), not
the invariant this Spec verifies.

## Threat Model Impact

This Spec is the single largest evidence source for EPIC-TM-01 — all
seven trust-boundary crossings the threat model needs to reason about are
enumerated here first.

## Operational Impact

Should run as a CI check once `infrastructure/` has real modules (I23
territory) — not yet wired since `infrastructure/` is empty; tracked as a
follow-on enabler once `SPEC-NET-001`..`004`/`006` land.

## Rollback / Recovery

N/A — this Spec provisions nothing, so there is nothing to roll back. A
failing verification blocks merge of whatever change broke it, under the
same Definition of Done as any other Spec.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
