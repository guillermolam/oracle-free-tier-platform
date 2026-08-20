# Architecture Decision Records

Each ADR is one file: `ADR-NNNN-short-title.md`, status one of `Proposed`,
`Accepted`, `Superseded`, `Deprecated`. Propose new ones with the
`Architecture` issue template (`.github/ISSUE_TEMPLATE/architecture.yml`).

| ADR | Title | Status |
| --- | --- | --- |
| [ADR-0001](ADR-0001-opentofu-terragrunt.md) | OpenTofu + Terragrunt for infrastructure as code | Accepted |
| [ADR-0002](ADR-0002-talos-node-os.md) | Talos as the node operating system | Accepted |
| [ADR-0003](ADR-0003-openziti-ztna.md) | OpenZiti for zero-trust administrative access | Accepted |
| [ADR-0004](ADR-0004-kyverno-policy-engine.md) | Kyverno as the admission policy engine | Accepted |
| [ADR-0005](ADR-0005-flux-gitops.md) | Flux as the sole Kubernetes GitOps controller | Accepted |
| [ADR-0006](ADR-0006-trust-zone-network-segmentation.md) | Four-zone trust-boundary network segmentation | Accepted |
| [ADR-0007](ADR-0007-terragrunt-state-boundaries.md) | Terragrunt state boundary architecture for OCI live environments | Accepted |
| [ADR-0008](ADR-0008-drg-reserved-inert-m1.md) | Reserve the DRG in M1; defer hybrid routing to I21 | Accepted (mechanism amended by ADR-0009) |
| [ADR-0009](ADR-0009-drg-reuse-and-strip-inert-table.md) | DRG inert route table — reuse-and-strip the auto-created table | Accepted |

ADR-0001 through ADR-0005 record decisions that were already implicit in
`CONTRIBUTING.md`'s ownership model before any ADR existed; they catch the
decision record up to reality rather than proposing something new. ADR-0006
records the network shape already drawn in
[`docs/arch/cloud-deployment.mmd`](../arch/cloud-deployment.mmd). ADR-0007
and ADR-0008 are genuine decisions-with-alternatives reached during M1
specification and use a fuller field set (Options considered, Decision
drivers, Security/Operational consequences, Reversibility, Related Specs) —
use that richer shape for future ADRs that weigh real alternatives; the
lighter shape stays fine for decisions that only need to be caught up to
reality.
