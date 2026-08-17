# oracle-free-tier-platform

A zero-trust Kubernetes platform on Oracle Cloud Infrastructure's Always
Free tier, built entirely as Infrastructure as Code + GitOps: OCI network
foundation, Talos Kubernetes, Cilium, OpenZiti ZTNA, SPIFFE/SPIRE workload
identity, OpenBao + External Secrets Operator, Flux GitOps, Kyverno policy,
and a demonstrated backup/restore drill — reproducible from `tofu apply`
and a Flux bootstrap, with nothing hand-run against production. See
[docs/00-overview/vision.md](docs/00-overview/vision.md) for the full
problem statement, users, and success metrics.

## Status

**Greenfield.** Governance scaffolding, specifications, and architecture
documentation exist; no OpenTofu modules or running infrastructure yet.
Check [docs/00-overview/roadmap.md](docs/00-overview/roadmap.md) for the
milestone actually in progress before assuming a component exists — do not
infer implementation status from this README.

## Technology decisions vs. open questions

Settled, recorded as ADRs (`docs/02-decisions/`): OpenTofu + Terragrunt for
IaC ([ADR-0001](docs/02-decisions/ADR-0001-opentofu-terragrunt.md)), Talos
as node OS ([ADR-0002](docs/02-decisions/ADR-0002-talos-node-os.md)),
OpenZiti for zero-trust admin access
([ADR-0003](docs/02-decisions/ADR-0003-openziti-ztna.md)), Kyverno as the
policy engine ([ADR-0004](docs/02-decisions/ADR-0004-kyverno-policy-engine.md)),
Flux as the sole GitOps controller
([ADR-0005](docs/02-decisions/ADR-0005-flux-gitops.md)), a four-zone trust
network segmentation
([ADR-0006](docs/02-decisions/ADR-0006-trust-zone-network-segmentation.md)),
Terragrunt state boundaries
([ADR-0007](docs/02-decisions/ADR-0007-terragrunt-state-boundaries.md)), and
the DRG staying reserved-but-inert through M1
([ADR-0008](docs/02-decisions/ADR-0008-drg-reserved-inert-m1.md)). See the
[ADR index](docs/02-decisions/README.md) for the full list and status.

Still open, tracked as spikes rather than assumed: storage engine
(SPIKE-STOR-01), container runtime alternative (SPIKE-RT-01), Ampere A1
shape split (SPIKE-COMP-01), IdP choice (SPIKE-IDP-01), SPIFFE federation
(SPIKE-SPIFFE-01), cross-cloud ClusterMesh (SPIKE-HYBRID-01) — see
[roadmap.md](docs/00-overview/roadmap.md#open-spikes) for what each blocks.

## Ownership boundaries

Fixed and non-negotiable without a superseding ADR: **OpenTofu** provisions
OCI resources, **Terragrunt** owns environment composition and state
boundaries, **Talos** owns node configuration (no SSH), **Flux** owns
Kubernetes desired state (GitHub Actions validates and plans only — it
never deploys), and **Cilium / SPIRE / OpenBao+ESO / Kyverno** each own
their respective control plane. Full detail in
[CONTRIBUTING.md](CONTRIBUTING.md#ownership-model).

## Security and identity model

Administrative access to the Kubernetes API has no direct internet path:
administrator → OpenZiti public edge router (Edge zone) → Ziti fabric →
Ziti private router (Management zone) → `kube-apiserver`
([ADR-0003](docs/02-decisions/ADR-0003-openziti-ztna.md)). The VCN is
segmented into four trust zones — Edge, Management, Workload, Data — with
Edge the only zone permitted a public IP
([ADR-0006](docs/02-decisions/ADR-0006-trust-zone-network-segmentation.md)).
Cross-domain identity (GitHub, OCI IAM, human IdP, OpenZiti, Kubernetes
RBAC, ServiceAccount, SPIFFE, OpenBao, Flux) is reconciled explicitly in
[docs/01-architecture/identity-reconciliation.md](docs/01-architecture/identity-reconciliation.md) —
similarly-named principals across systems are not assumed to be the same
one unless a mapping mechanism is documented. Threat modeling (DFDs, attack
paths, risk register) has not started yet — see
[docs/03-threat-model/README.md](docs/03-threat-model/README.md) for the
planned evidence chain and [SECURITY.md](SECURITY.md) for vulnerability
reporting.

## Specification-driven delivery model

`docs/specs/SPEC-<AREA>-<NNN>.md` is the canonical, versioned record of
**what** a capability must do and **why** — numbered `REQ-*` requirements,
acceptance criteria, and Diagram/ADR/Threat-Model impact. GitHub issues
(Feature / Story / Enabler / Spike) are thin execution contracts that point
at a Spec rather than restating it:

```text
docs/specs/SPEC-<AREA>-NNN.md   <- canonical WHAT + WHY + contract
             |
             v
     GitHub Feature/Story/Enabler/Spike   <- disposable execution tracking
             |
             v
         Pull Request  ->  Tests, ADR, Diagrams  ->  Spec verified
```

See [docs/specs/README.md](docs/specs/README.md) for the full contract,
template, and Definition of Ready/Done.

## Architecture: L0-L4 multi-view model

One architecture, multiple viewpoints, one set of shared contracts (the
Specs). Each diagram is a **projection**, not an independent source of
truth, and traces back through a stable `ARCH-*` concept ID rather than a
volatile Mermaid node name:

| Level | Question |
| --- | --- |
| L0 — System Context | What is this platform and what external systems interact with it? |
| L1 — Cloud Deployment | Where are the major platform components deployed? |
| L2 — Domain Architecture | How does one platform domain work? |
| L3 — Component/Zone Detail | How is this particular domain or trust zone configured? |
| L4 — Dynamic/Flow View | What happens during a particular operation? |

`mmdc` (Mermaid CLI, pinned in `package.json`) is the authoritative
validator for every `.mmd` file — an editor preview is not. See
[docs/01-architecture/README.md](docs/01-architecture/README.md) for
navigation and [views.md](docs/01-architecture/views.md) for the full view
catalog, and [traceability.md](docs/01-architecture/traceability.md) for
the Spec → ARCH-* → view → Mermaid chain.

## Repository navigation

```text
docs/00-overview/       vision, personas, roadmap
docs/01-architecture/   L0-L4 architecture views (+ docs/arch/cloud-deployment.mmd)
docs/02-decisions/      ADRs
docs/03-threat-model/   threat model (not started — I20)
docs/04-operations/     operational runbooks (not started)
docs/05-security/       security architecture (not started)
docs/06-runbooks/       incident/operational runbooks (not started)
docs/specs/             canonical Spec files (SPEC-<AREA>-NNN.md)
infrastructure/         OpenTofu modules/compositions, Terragrunt live envs (empty — greenfield)
scripts/                validation helpers (Mermaid, GPG-signing config check)
.github/                CI workflows, issue/PR templates, label taxonomy
```

## Roadmap

25 initiatives (I01-I25) decompose into epics, specs, and GitHub-tracked
stories/enablers/spikes across milestones M0-M12 (M0-M10 in MVP scope,
M11-M12 explicitly deferred). See
[docs/00-overview/roadmap.md](docs/00-overview/roadmap.md) for the critical
path, milestone table, and MVP definition.

## Validation

```sh
pre-commit run --all-files                    # full local validation gate
npm run validate:mermaid                      # render every docs/**/*.mmd with mmdc
npx markdownlint-cli2 --config .markdownlint-cli2.yaml \
  "docs/**/*.md" "*.md" ".github/**/*.md"     # matches CI's docs.yml
```

Once `infrastructure/modules/` or `infrastructure/compositions/` exist:
`tofu fmt -recursive infrastructure`, `tflint --recursive`,
`checkov -d infrastructure`, and — per directory containing `main.tf` —
`tofu init -backend=false && tofu validate` (never an unqualified
`tofu validate` from the repo root). Full command set and rationale in
[AGENTS.md](AGENTS.md#build-test-and-development-commands).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branch/PR workflow and
[AGENTS.md](AGENTS.md) for full repository guidance (structure, commands,
conventions, hook setup) — the canonical instruction file for both human
and agent contributors. `CLAUDE.md` is a symlink to it.
