# SPEC-OCI-003 — OCI Logging, Monitoring, and Audit Foundation

**Status:** Ready
**Initiative:** I02 OCI Cloud Foundation
**Epic:** EPIC-OCI-06

## Context

`docs/arch/cloud-deployment.mmd` depicts OCI Logging and Monitoring at
platform-compartment scope and OCI Audit at tenancy scope. `SPEC-OCI-001`
deferred all three as a Non-Goal.

## Problem Statement

No log groups or monitoring scaffolding exist. I16 (Observability) needs
somewhere at the OCI layer to land infrastructure-level signal — VCN flow
logs, IAM audit correlation, resource health — distinct from in-cluster
application observability (Prometheus/Loki/Tempo, a different layer
entirely). `SPEC-NET-004`'s Observability Requirements section already
flagged NSG deny events as "out of scope for this Spec, noted for I16 to
pick up" — this Spec is the OCI-layer half of closing that gap.

## Goals

- A dedicated OCI Log Group exists in the platform compartment.
- VCN flow logging is enabled for the `SPEC-NET-001` VCN, routed to that
  Log Group.
- OCI Audit is confirmed active with default retention.

## Non-Goals

- Grafana/Prometheus/Loki (I16, in-cluster).
- Alerting/notification topics wired to a human (I24 runbook territory).

## Requirements

- **REQ-OCI-012** The platform MUST provision a dedicated OCI Log Group in
  the platform compartment for infrastructure-level logs.
- **REQ-OCI-013** The platform MUST enable VCN flow logging for the
  `SPEC-NET-001` VCN, routed to the Log Group from REQ-OCI-012.
- **REQ-OCI-014** OCI Audit (tenancy-native, always-on) MUST be confirmed
  active, and its retention MUST NOT be reduced below OCI's default.
- **REQ-OCI-015** IAM policy MUST grant log-write access only to the
  specific OCI services/dynamic groups that need it — no broad `manage
  logging-family` grant.

## Constraints

OCI Free Tier: stay within default log ingestion/retention allowances —
no extended/archival retention requiring a paid tier. REQ-OCI-013 needs
`SPEC-NET-001`'s VCN to exist, so — unlike `SPEC-OCI-002` — this module
depends on both `00-foundation` and `10-network` (see
[ADR-0007](../02-decisions/ADR-0007-terragrunt-state-boundaries.md)).
Module lives under `infrastructure/modules/logging-monitoring`.

## Interfaces

**Input:** `compartment_ocid` (`SPEC-OCI-001`), `vcn_id` (`SPEC-NET-001`).
**Output:** `log_group_id`. Consumed by: I16 (Observability), for
OCI-layer log correlation.

## Dependencies

`SPEC-OCI-001`, `SPEC-NET-001` (VCN flow-log attachment).

## Security Requirements

Least-privilege log-write policy (REQ-OCI-015); audit retention floor
(REQ-OCI-014) — reducing audit retention is itself a security-relevant
action requiring explicit justification, not a default option.

## Failure Modes

Flow logging misconfigured or disabled → `SPEC-NET-004`'s NSG deny events
become invisible, weakening the threat model's detective controls;
EPIC-TM-01 will flag this as a gap if REQ-OCI-013 isn't satisfied. Audit
retention silently reduced → REQ-OCI-014 violation, caught by review.

## Observability Requirements

This Spec **is** the OCI-layer observability foundation — self-referential,
no further requirement beyond its own REQs.

## Acceptance Criteria

```text
Given the logging-monitoring module is applied in the lab environment
When `tofu apply` completes
Then a dedicated OCI Log Group exists in the platform compartment
And VCN flow logging is enabled for the SPEC-NET-001 VCN, targeting that
  Log Group
And OCI Audit is confirmed ACTIVE with default retention
```

## Verification

```bash
tofu validate
tofu test
oci logging log-group list --compartment-id "$C"
oci logging log list --log-group-id "$LG" \
  --query "data[?\"log-type\"=='SERVICE']"
oci audit configuration get --compartment-id "$TENANCY"
```

## Documentation Impact

`docs/01-architecture/foundation.md` — Logging/Monitoring/Audit section.

## Diagram Impact

Architecture Impact: `ARCH-SVC-LOGGING`, `ARCH-SVC-MONITORING`,
`ARCH-GOV-TENANCY`.
Diagram: `docs/arch/cloud-deployment.mmd` (working-tree draft, not yet
canonicalized — see
[`docs/01-architecture/traceability.md`](../01-architecture/traceability.md)).

## ADR Impact

[ADR-0007](../02-decisions/ADR-0007-terragrunt-state-boundaries.md) — this
Spec is why the `logging-monitoring` state unit depends on `10-network`
unlike `20-security/kms`.

## Threat Model Impact

REQ-OCI-013's VCN flow logs feed EPIC-TM-01's detective-control inventory
directly — this is how "no unauthorized zone-to-zone traffic"
(`SPEC-NET-004`'s Threat Model Impact claim) becomes *observable*, not
just enforced.

## Operational Impact

Log retention/cost monitoring is a day-2 concern (I24) once volume is
non-trivial — post-M2, once compute exists and generates real flow-log
volume.

## Rollback / Recovery

Safe to `tofu destroy` pre-I16 consumption. Disabling flow logs
temporarily (e.g., a cost concern) is a documented, reviewed exception,
never silent.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
