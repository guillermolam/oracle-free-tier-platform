# SPEC-OCI-001 — OCI Tenancy, Compartment, IAM, and State Foundation

**Status:** Ready
**Initiative:** I02 OCI Cloud Foundation
**Epic:** EPIC-OCI-01, EPIC-OCI-03

## Context

No OCI resource exists yet. Every subsequent Spec (network, compute,
storage) needs somewhere to live that isn't the tenancy root, and OpenTofu
needs a state backend that isn't a local file. This is the root of the
dependency graph — nothing else in I02/I03 can start without it.

## Problem Statement

Provisioning directly into the tenancy root compartment with no dedicated
IAM scope makes least-privilege enforcement and blast-radius containment
impossible, and local `tofu` state cannot survive a CI runner disappearing
between plan and apply.

## Goals

- A dedicated platform compartment isolates all platform resources from the
  tenancy root.
- IAM policy grants exactly the access the platform needs, scoped to that
  compartment.
- OpenTofu state is stored remotely, versioned, and not lost if a runner is
  destroyed.

## Non-Goals

- KMS, Logging, and Monitoring service configuration (own Specs, not yet
  written — tracked in `docs/00-overview/roadmap.md` under I02).
- OCI OIDC federation for CI (EPIC-OCI-04 — static keys are in scope for
  this Spec; OIDC is a follow-on).

## Requirements

- **REQ-OCI-001** The platform MUST provision a dedicated OCI Compartment
  for all platform resources, as a child of the tenancy root compartment,
  never provisioning platform resources directly into the root.
- **REQ-OCI-002** The platform MUST define IAM policies scoped to the
  platform compartment only — no policy statement may grant access at the
  tenancy level.
- **REQ-OCI-003** The platform MUST define Dynamic Groups matching
  Talos/Flux-managed instance principals, so in-cluster workloads
  authenticate to OCI APIs (Object Storage, KMS) via instance principal,
  never via long-lived static keys embedded in the cluster.
- **REQ-OCI-004** The platform MUST apply Defined Tags
  (`platform=oracle-free-tier`, `environment=<lab|staging|prod>`) to every
  resource provisioned under the platform compartment.
- **REQ-OCI-005** OpenTofu state MUST be stored in a dedicated OCI Object
  Storage bucket with versioning enabled, never in local state files or a
  third-party state SaaS.
- **REQ-OCI-006** Tenancy-level OCI credentials (tenancy/user OCID,
  fingerprint, private key) MUST be supplied to CI exclusively via GitHub
  Actions encrypted secrets until EPIC-OCI-04 replaces them with OIDC
  federation.

## Constraints

OCI Free Tier (compartments and IAM policies carry no cost); single region
initially (`eu-madrid-1`, per `plan.yml`); Terragrunt owns environment
composition and state boundaries (ADR-0001) — this Spec's module is
consumed once per environment under `infrastructure/live/oci/eu-madrid-1/
<env>/`.

## Interfaces

**Input:** `tenancy_ocid`, `region` (vars, sourced from CI secrets or local
`oci` CLI config). **Output:** `compartment_ocid`. Consumed by:
`SPEC-NET-001` and every subsequent OCI resource module.

## Dependencies

None — this is the root of the dependency graph. Blocks `SPEC-NET-001`.

## Security Requirements

Least privilege: IAM policy statements enumerate specific verbs/resource
types, never `manage all-resources`. No policy may reference the tenancy
root compartment as its target. The state bucket itself must not be
publicly accessible and must use server-side encryption.

## Failure Modes

- State bucket accidentally made public → `checkov` policy scan (already in
  `validate.yml`) must flag public Object Storage misconfiguration; this is
  a merge-blocking failure, not a warning.
- Dynamic Group match rule omitted or wrong → instance principal auth fails
  closed (no access), never silently falls back to a broader grant.

## Observability Requirements

`tofu plan` output is attached to the PR (`plan.yml`, already live). No
runtime signal exists yet — this Spec has no running component.

## Acceptance Criteria

```
Given the OCI foundation module is applied in the lab environment
When `tofu apply` completes
Then a platform compartment exists as a child of the tenancy root compartment
And IAM policies grant access scoped to that compartment only
And `tofu state show` on the state resource confirms an OCI Object Storage
  backend, not local state
```

## Verification

```
tofu validate
oci iam compartment list --compartment-id-in-subtree true \
  --query "data[?name=='platform']"
tofu state list  # confirms backend is remote (oci), not local
```

## Documentation Impact

`docs/01-architecture/foundation.md` (new) — compartment hierarchy, IAM
policy scope, dynamic group match rules, state backend location.

## Diagram Impact

None beyond `docs/arch/cloud-deployment.mmd`'s existing tenancy-level IAM/
policies/dynamic-groups/tags depiction.

## ADR Impact

[ADR-0001](../02-decisions/ADR-0001-opentofu-terragrunt.md) (records the
IaC ownership split this Spec's module structure follows).

## Threat Model Impact

Establishes the IAM trust boundary between tenancy root and platform
compartment — feeds EPIC-TM-01 (I20) directly once that epic starts.

## Operational Impact

Compartment/IAM changes are rare post-bootstrap. Day-2 concern is the
credential rotation cadence ahead of EPIC-OCI-04's OIDC migration —
tracked under I24 once that runbook exists.

## Rollback / Recovery

`tofu destroy` is unsafe once any downstream resource references the
compartment. Rollback is a new PR reverting the policy/compartment change,
never a manual console edit (`SECURITY.md`).

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
