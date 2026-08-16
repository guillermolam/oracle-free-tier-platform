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

ADR-0001 through ADR-0005 record decisions that were already implicit in
`CONTRIBUTING.md`'s ownership model before any ADR existed; they catch the
decision record up to reality rather than proposing something new. ADR-0006
records the network shape already drawn in
[`docs/arch/cloud-deployment.mmd`](../arch/cloud-deployment.mmd).
