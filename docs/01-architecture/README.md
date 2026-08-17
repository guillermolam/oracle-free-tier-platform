# Architecture

One architecture, multiple viewpoints, different abstraction levels, one
set of shared architectural contracts (the Specs). A diagram is a
**projection** of the architecture, not an independent source of truth —
see [`traceability.md`](traceability.md) for the chain from Spec to
concept ID to view to Mermaid implementation.

We do not solve growing architectural complexity by continuously expanding
one diagram. **A diagram must have a question.** If two diagrams answer
different questions, maintaining both is valid — see
[`traceability.md`](traceability.md#dry-does-not-mean-zero-duplication) for
why that isn't a DRY violation. If two diagrams answer the *same* question
with conflicting architecture, that's drift: a bug, not a style choice.

## View levels

| Level | Question | Examples in this repo |
| --- | --- | --- |
| **L0 — System Context** | What is this platform and what external systems interact with it? | `context/platform-context.mmd` |
| **L1 — Cloud Deployment** | Where are the major platform components deployed? | `docs/arch/cloud-deployment.mmd` |
| **L2 — Domain Architecture** | How does one platform domain work? | `network/network-overview.mmd`, `network/traffic-flows.mmd`, `identity/oci-identity-governance.mmd`, `identity/human-identity.mmd`, `governance/platform-governance.mmd`, `cicd/software-supply-chain.mmd` |
| **L3 — Component / Zone Detail** | How is this particular domain or trust zone configured? | `network/routing.mmd`, `network/edge-zone.mmd`, `network/management-zone.mmd`, `network/workload-zone.mmd`, `network/data-zone.mmd`, `governance/oci-access-control.mmd`, `identity/openziti-identity-network.mmd`, `cicd/iac-pipeline.mmd` |
| **L4 — Dynamic / Flow View** | What happens during a particular operation? | none yet — see `views.md`'s Dynamic flow views note |

Diagrams may intentionally repeat architectural concepts across levels —
`VCN 10.10.0.0/16` appears at every level above L0. That's expected, not
duplication to eliminate.

## On `docs/arch/cloud-deployment.mmd`

This file predates the multi-view model and remains the L1 Cloud
Deployment view — the single most detailed picture of the whole system.
It stays at its current path; nothing here moves or renames it. As domain
and zone-detail views absorb more of what it currently shows (network
segmentation → `network-overview.mmd`, routing → `routing.mmd`, and so
on), it's expected to simplify over time toward a true L1 overview rather
than growing further — but that's a future edit to that file by whoever
owns it next, not something this pass performs. See
[`traceability.md`](traceability.md#status-of-diagram-artifacts) for its
current commit status.

## Full catalog

See [`views.md`](views.md) for every active view (ID, level, purpose,
audience, scope, out-of-scope, governing Specs, status) and every
registered-but-not-yet-elaborated planned view.

## Navigation

```text
Architecture
    │
    ├── Context          (context/platform-context.mmd)
    ├── Deployment        (../arch/cloud-deployment.mmd)
    ├── Network
    │     ├── Overview     (network/network-overview.mmd)
    │     ├── Routing       (network/routing.mmd)
    │     ├── Traffic       (network/traffic-flows.mmd)
    │     ├── Edge          (network/edge-zone.mmd)
    │     ├── Management     (network/management-zone.mmd)
    │     ├── Workload       (network/workload-zone.mmd)
    │     └── Data            (network/data-zone.mmd)
    │
    ├── Identity
    │     ├── OCI Identity      (identity/oci-identity-governance.mmd)
    │     ├── Human Identity      (identity/human-identity.mmd)
    │     ├── OpenZiti              (identity/openziti-identity-network.mmd)
    │     ├── Workload Identity        — planned, I09 (views.md)
    │     └── Kubernetes RBAC             — planned, I05/I09/I10 (views.md)
    │
    ├── Governance
    │     ├── OCI Access Control   (governance/oci-access-control.mmd)
    │     ├── Platform Governance    (governance/platform-governance.mmd)
    │     └── Kubernetes Tenancy        — planned, I05 (views.md)
    │
    ├── Kubernetes
    │     ├── Deployment   — planned, I04/I05/I06 (views.md)
    │     ├── Network        — planned, I07 (views.md)
    │     └── Security Boundaries — planned, I05/I07/I09 (views.md)
    │
    ├── CI/CD
    │     ├── Supply Chain   (cicd/software-supply-chain.mmd)
    │     ├── IaC              (cicd/iac-pipeline.mmd)
    │     ├── Platform GitOps    — planned, I12 (views.md)
    │     ├── Application          — no owning initiative (views.md)
    │     ├── Policy                 — planned, I14 (views.md)
    │     ├── Node Configuration       — planned, I04 (views.md)
    │     └── Security Content           — planned, I17 (views.md)
    │
    ├── Security         — planned trust-boundaries synthesis, I08/I20 (views.md)
    ├── Storage              — planned, I15 (views.md)
    ├── Observability          — planned, I16 (views.md)
    └── Hybrid                    — planned, I21 (views.md)
```

## Diagrams to be added as their owning Spec ships

Non-Mermaid documentation, added by the PR that implements the Spec
listed, not before — avoids documentation drifting ahead of what's
actually built.

| Doc | Owning Spec / Initiative |
| --- | --- |
| `network.md` (CIDR + zone-to-subnet reference table) | SPEC-NET-001 |
| Kubernetes bootstrap sequence | I05 |
| Identity architecture (SPIFFE + human IdP) | I09, I10 |
| Secrets/PKI architecture | I11 |
| Storage architecture | I15 |
| Observability architecture | I16 |
| DFD L0/L1 + trust boundaries | I20 (EPIC-TM-01) — see [docs/03-threat-model](../03-threat-model/README.md) |

## Foundation account/compartment layout

Added by `SPEC-OCI-001` once implemented (`foundation.md`): compartment
hierarchy, IAM policy scope, dynamic group match rules, tofu state backend
location.
