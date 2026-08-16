# SPEC-OCI-002 — OCI Vault and KMS Foundation

**Status:** Ready
**Initiative:** I02 OCI Cloud Foundation
**Epic:** EPIC-OCI-05

## Context

`SPEC-OCI-001` explicitly deferred KMS as a Non-Goal. `docs/arch/cloud-deployment.mmd`
depicts OCI Vault/KMS at the platform-compartment level. This Spec closes
that gap.

## Problem Statement

No encryption-key-management foundation exists. The state bucket
(`SPEC-OCI-001`, REQ-OCI-005) relies on Oracle-managed encryption today;
every future secret/PKI initiative (I11) and storage initiative (I15/I19)
will need a platform-owned Vault to reference.

## Goals

- A Vault exists in the platform compartment.
- A master encryption key is provisioned within it.
- IAM policy grants key-usage rights only to the specific principals that
  need them.

## Non-Goals

- Actual application/PKI use of the key (I11 owns that).
- Customer-managed encryption on the state bucket itself — optional
  follow-on, not required (REQ-OCI-005 is already satisfied by Oracle-managed
  encryption).

## Requirements

- **REQ-OCI-008** The platform MUST provision an OCI Vault of type
  `DEFAULT` (Free Tier eligible) in the platform compartment.
- **REQ-OCI-009** The platform MUST provision at least one master
  encryption key within that Vault, scoped for platform use.
- **REQ-OCI-010** IAM policy MUST grant key-usage rights (`use keys`,
  `use key-delegate`) only to the specific dynamic groups/principals that
  require them — no policy may grant vault/key management rights broadly.
- **REQ-OCI-011** The Vault and its keys MUST NOT be deleted or scheduled
  for deletion without a documented, reviewed exception — OCI key deletion
  carries an irreversible-after-waiting-period risk.

## Constraints

OCI Free Tier: a `DEFAULT` Vault has a Free Tier allowance; a
`VIRTUAL_PRIVATE` Vault does not — this Spec MUST use `DEFAULT`. Module
lives under `infrastructure/modules/kms` — a separate OpenTofu module and
Terragrunt state unit from network/foundation (see
[ADR-0007](../02-decisions/ADR-0007-terragrunt-state-boundaries.md)), because
key-material blast radius and lifecycle differ fundamentally from both.

## Interfaces

**Input:** `compartment_ocid` (from `SPEC-OCI-001`). **Output:** `vault_id`,
`master_key_id`. Consumed by: future I11 Specs (secrets/PKI), optionally
I15/I19 (encrypted backups).

## Dependencies

`SPEC-OCI-001` (compartment). Independent of `SPEC-NET-*` — per
[ADR-0007](../02-decisions/ADR-0007-terragrunt-state-boundaries.md)'s
dependency graph.

## Security Requirements

Least-privilege key-usage policy (REQ-OCI-010); no policy may grant
`manage vaults` or `manage keys` broadly; key deletion protection
(REQ-OCI-011).

## Failure Modes

Key deletion accidentally scheduled → OCI enforces a mandatory waiting
period as a platform-level safety net, but REQ-OCI-011 requires this
repo's own process to never allow it silently — any PR touching key
lifecycle needs the `risk/critical` label and explicit review per
`SECURITY.md`. IAM policy accidentally grants broad key management →
caught by REQ-OCI-010's `tofu test` coverage once implemented.

## Observability Requirements

`tofu plan` output attached to PR. Vault/key operations flow through
`ARCH-GOV-TENANCY`'s OCI Audit automatically — no extra configuration
needed for a basic audit trail.

## Acceptance Criteria

```text
Given the kms module is applied in the lab environment
When `tofu apply` completes
Then an OCI Vault of type DEFAULT exists in the platform compartment
And at least one master encryption key exists within it
And IAM policy grants key-usage rights only to the dynamic groups named
  in REQ-OCI-010's scope, not tenancy-wide
```

## Verification

```bash
tofu validate
tofu test
oci kms management vault list --compartment-id "$C" \
  --query "data[?\"lifecycle-state\"=='ACTIVE']"
oci iam policy list --compartment-id "$C" \
  --query "data[?contains(statements[0], 'use keys')]"
```

## Documentation Impact

`docs/01-architecture/foundation.md` — Vault/KMS section (extends the doc
`SPEC-OCI-001` promised).

## Diagram Impact

Architecture Impact: `ARCH-SVC-KMS`, `ARCH-GOV-TENANCY`.
Diagram: `docs/arch/cloud-deployment.mmd` (working-tree draft, not yet
canonicalized — see
[`docs/01-architecture/traceability.md`](../01-architecture/traceability.md)).

## ADR Impact

None beyond [ADR-0001](../02-decisions/ADR-0001-opentofu-terragrunt.md)
(module ownership) and
[ADR-0007](../02-decisions/ADR-0007-terragrunt-state-boundaries.md) (why
KMS is its own state unit). A future ADR may be warranted if/when I11
chooses between OCI Vault-issued keys and OpenBao-managed keys for
workload secrets — not this Spec's concern.

## Threat Model Impact

Establishes `ARCH-SVC-KMS` as an asset in EPIC-TM-01's future inventory —
key compromise is a high-severity threat to be modeled once that epic
starts.

## Operational Impact

Key rotation policy is a day-2 concern (I24, once that runbook exists);
OCI supports automatic key rotation, which SHOULD be enabled once I11
defines a rotation cadence — not required by this Spec.

## Rollback / Recovery

`tofu destroy` is safe only if REQ-OCI-011's exception process is followed
and nothing yet consumes the key (true in M1). Once I11 starts consuming
it, rollback becomes a documented key-rotation event, never a deletion.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
