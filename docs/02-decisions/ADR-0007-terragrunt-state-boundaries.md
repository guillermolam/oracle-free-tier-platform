# ADR-0007: Terragrunt state boundary architecture for OCI live environments

Status: Accepted

## Context

`SPEC-OCI-001` through `SPEC-NET-006` define *what* M1 must provision, but
not how OpenTofu state is partitioned across Terragrunt units. State
boundaries determine blast radius directly — a `tofu apply` in one unit
can only affect the resources tracked in that unit's state — so this is a
durable architectural decision, not an implementation detail.

State backend creation is also inherently chicken-and-egg (REQ-OCI-007):
the bucket that holds remote state cannot itself be backed by that same
remote state on its first apply.

## Decision

**Options considered:**

- **A. Monolithic** — one state for the entire OCI live environment.
- **B. Fine-grained** — one unit per resource type, mirroring the
  diagram's every node (`vcn/`, `edge-subnet/`, `management-subnet/`,
  `workload-subnet/`, `data-subnet/`, `gateways/`, `routes/`, `nsg/`,
  `kms/`, `logging/`, `monitoring/`, ...) — roughly 15 units for M1 alone.
- **C. Boundaries derived from actual blast-radius/lifecycle/ownership/
  recoverability properties**, collapsing tightly-coupled resources and
  splitting only where those properties genuinely diverge.

**Decision drivers:** blast-radius containment; whether resources change
together in practice (lifecycle synchronization); ownership/initiative
alignment; dependency direction (avoid circular references between
units); recoverability cost if a unit's state is lost or corrupted; and
avoiding Terragrunt/OpenTofu operational overhead disproportionate to
actual independent-deploy value at this project's scale (single
maintainer, single region, Free Tier).

**Decision: Option C.** For M1:

```text
live/oci/eu-madrid-1/lab/
  00-foundation/            SPEC-OCI-001 — compartment, IAM, dynamic
                            groups, tags, state-backend bucket
                            (self-hosts its own REQ-OCI-007 bootstrap)
  10-network/                SPEC-NET-001, 002, 003, 004, 006 — VCN,
                            subnets, gateways (incl. inert DRG), route
                            tables, NSGs + Security Lists, VCN DNS/DHCP —
                            one OpenTofu module
                            (infrastructure/modules/network), one state
                            unit
  20-security/
    kms/                     SPEC-OCI-002 — OCI Vault + KMS
    logging-monitoring/      SPEC-OCI-003 — OCI Logging, Monitoring, Audit
```

Dependency direction:

```text
00-foundation
  ├──> 10-network
  ├──> 20-security/kms
  └──> 10-network ──> 20-security/logging-monitoring
```

`20-security/kms` depends only on `00-foundation`. `20-security/
logging-monitoring` depends on **both** `00-foundation` and `10-network`,
because REQ-OCI-013 (VCN flow logs) needs the VCN to exist first — this
asymmetry is a real, evidence-based dependency, not an oversight.

`00-foundation` is rejected as a further-split target (Option B would
separate compartment/IAM/tags into 3 units) because they share one blast
radius (everything downstream depends on the compartment existing) and one
lifecycle (essentially create-once).

`10-network` is rejected as a further-split target because OCI network
topology within one VCN is provisioned and changed as a unit in practice —
`SPEC-NET-001` through `SPEC-NET-006` already model it as one OpenTofu
module (see each Spec's Interfaces section), and splitting subnets/
gateways/routes/NSGs into 4–6 separate state units would multiply `tofu
apply` operations for a change that is, in practice, atomic (a new subnet
implies a new route table and NSG in the same PR).

`20-security/kms` and `20-security/logging-monitoring` **are** split from
each other and from `10-network`, because: KMS key deletion carries
irreversible, delayed-deletion risk fundamentally different from
recreatable logging/monitoring configuration (blast radius); KMS is
expected to be near-zero-churn after creation while logging/monitoring
configuration will iterate as I16 matures (lifecycle); and neither needs
to block on the other (dependency direction).

`SPEC-NET-005` (traffic-flow invariants) has **no** Terragrunt state
unit — it provisions nothing; it is a verification layer that runs
assertions against `10-network`'s already-applied outputs.

**Not addressed by this ADR (deferred):** `40-storage` (backup bucket,
I19/M9) and a possible future `90-hybrid` split of DRG route management
out of `10-network` once I21 begins populating real hybrid routes — at
that point the DRG's lifecycle will diverge from the otherwise-static
network layer, which would justify splitting it out. Revisit at I21;
don't split now (see [ADR-0008](ADR-0008-drg-reserved-inert-m1.md)).

## Consequences

4 Terragrunt units for M1 instead of ~15. Fewer state files, fewer `tofu
apply` round trips — but a change to a single network sub-resource (e.g.,
one NSG rule) requires planning/applying the whole `10-network` unit
rather than a narrower one. Acceptable given this repo's single-maintainer
scale and the coupling already established by `SPEC-NET-001`–`004`/`006`
sharing one OpenTofu module.

## Security consequences

`00-foundation`'s outsized blast radius (losing it threatens every other
unit's ability to manage state) is mitigated by REQ-OCI-005's bucket
versioning and the bucket's required non-public configuration
(Checkov-enforced per `SPEC-OCI-001`). `20-security/kms` being isolated
from `10-network` means a network change can never accidentally touch key
material.

## Operational consequences

Bootstrap order is strict: `00-foundation` first (self-bootstrapping per
REQ-OCI-007), then `10-network` and `20-security/*` in either order.
`20-security/logging-monitoring` additionally requires `10-network` to
have been applied first.

## Reversibility

Splitting a unit later (e.g., extracting DRG route management into
`90-hybrid`) is a state-migration operation (`tofu state mv` into a new
backend key), not a redesign — low cost to defer. Merging units later is
higher cost (state must be manually consolidated) — this is why
`00-foundation` and `10-network` are kept appropriately narrow now rather
than starting monolithic (Option A) and hoping to split later.

## Related Specs

`SPEC-OCI-001`, `SPEC-OCI-002`, `SPEC-OCI-003`, `SPEC-NET-001`,
`SPEC-NET-002`, `SPEC-NET-003`, `SPEC-NET-004`, `SPEC-NET-005`,
`SPEC-NET-006`.
