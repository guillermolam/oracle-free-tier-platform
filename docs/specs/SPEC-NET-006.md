# SPEC-NET-006 — VCN DNS Resolver and DHCP Options

**Status:** Ready
**Initiative:** I03 Network & Trust-Zone Foundation
**Epic:** EPIC-NET-06

## Context

`docs/arch/cloud-deployment.mmd` depicts a VCN-scoped DNS resolver and
DHCP options set. OCI creates a default DHCP Options set automatically
with every VCN; this Spec covers making that choice explicit rather than
leaving it implicit.

## Problem Statement

Without explicit DNS/DHCP configuration, in-VCN service discovery relies
entirely on OCI's default behavior, which `SPEC-NET-001` through `004`
don't otherwise constrain — worth a small, explicit Spec so the choice
(default vs. custom) is a decision, not an accident.

## Goals

- The VCN has an explicit DNS label enabling OCI-internal DNS resolution.
- DHCP options are confirmed to use OCI's internal DNS resolver by
  default — no custom/external DNS server.

## Non-Goals

- Public DNS zone management (the diagram's public-DNS node is for the
  Edge-zone ingress' public-facing record — a separate concern from
  internal VCN resolution, not this Spec).
- Kubernetes-internal DNS (CoreDNS — I05/I07 territory).

## Requirements

- **REQ-NET-028** The platform MUST assign an explicit DNS label to the
  VCN enabling OCI-internal DNS resolution between subnets.
- **REQ-NET-029** The platform MUST use OCI's default internal DNS
  resolver in the VCN's DHCP Options set — no external/custom DNS server
  MAY be configured without a documented exception.
- **REQ-NET-030** DHCP Options MUST be an explicitly named OpenTofu
  resource, not left as OCI's auto-created default, so the choice in
  REQ-NET-029 is visible in code, not implicit.

## Constraints

Module lives under `infrastructure/modules/network` — same module as
`SPEC-NET-001` through `004` (one Terragrunt state unit, per
[ADR-0007](../02-decisions/ADR-0007-terragrunt-state-boundaries.md)). No
Free Tier cost implication.

## Interfaces

**Input:** `vcn_id` (`SPEC-NET-001`). **Output:** `dns_label`,
`dhcp_options_id`. Consumed by: I04 (compute, node-to-node resolution) and
I05 (Kubernetes bootstrap, before CoreDNS takes over pod-level
resolution).

## Dependencies

`SPEC-NET-001`. No other Spec depends on this one directly, though I04/I05
rely on it operationally.

## Security Requirements

REQ-NET-029's "no external DNS without a documented exception" prevents a
straightforward DNS-exfiltration/hijack vector (redirecting internal
resolution to an attacker-controlled resolver) from being introduced
casually.

## Failure Modes

A custom external DNS server added later without a documented exception →
REQ-NET-029 violation, caught in review. Surface area here is small enough
that automated `tofu test` coverage is optional, unlike `SPEC-NET-004`'s
higher-stakes NSG rules.

## Observability Requirements

None beyond standard `tofu plan` review — no runtime signal.

## Acceptance Criteria

```text
Given the network module is applied in the lab environment
When `tofu apply` completes
Then the VCN has an explicit DNS label
And the DHCP Options set is a named, explicit OpenTofu resource
And the DHCP Options set uses OCI's internal DNS resolver, not a custom
  external one
```

## Verification

```bash
tofu validate
oci network vcn get --vcn-id "$VCN" --query "data.\"dns-label\""
oci network dhcp-options list --compartment-id "$C" --vcn-id "$VCN" \
  --query "data[0].options"
```

## Documentation Impact

`docs/01-architecture/network.md` — DNS/DHCP note (small addendum to the
doc `SPEC-NET-001` promised).

## Diagram Impact

Architecture Impact: `ARCH-NET-DNS`, `ARCH-NET-VCN`.
Diagram: `docs/arch/cloud-deployment.mmd` (working-tree draft, not yet
canonicalized — see
[`docs/01-architecture/traceability.md`](../01-architecture/traceability.md)).

## ADR Impact

None.

## Threat Model Impact

REQ-NET-029 is a minor but real entry in EPIC-TM-01's future inventory
(DNS hijack/exfiltration vector, mitigated).

## Operational Impact

None day-2 beyond standard `tofu` drift detection (I23).

## Rollback / Recovery

Safe to `tofu destroy` pre-I04 attachment; after that, a new PR, never a
manual console edit.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
