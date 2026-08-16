# Product vision

## Problem

A real, production-grade, zero-trust Kubernetes platform costs real money on
every major cloud. OCI's Always Free tier (4 Ampere A1 ARM64 OCPUs / 24 GB
RAM, 200 GB block volume, 10 TB/month egress) makes a genuinely useful
private cluster possible at $0 — but only if the platform is architected
around that exact resource shape from the start, and built so it can grow
into hybrid and multi-cloud later without a rewrite.

## Users

- A solo/small-team platform engineer who wants a production-grade reference
  platform without a cloud bill.
- Autonomous engineering agents implementing the backlog issue by issue — see
  [docs/specs/README.md](../specs/README.md) for how work is specified for them.

## Desired outcome

Zero to a working, GitOps-reconciled, privately-networked Kubernetes cluster
— with workload identity, secrets, storage, observability, and backup — from
`tofu apply` and a Flux bootstrap, with nothing hand-run against production.

## Platform capabilities

OCI network/trust-zone foundation, Talos Kubernetes, Cilium, OpenZiti ZTNA,
SPIFFE/SPIRE workload identity, human IdP/OIDC, OpenBao + External Secrets
Operator + PKI, FluxCD GitOps, Argo Rollouts/Events, Kyverno policy,
Longhorn/SeaweedFS/OCI Object Storage, observability (metrics/logs/traces),
supply-chain security, backup/DR, and a path to hybrid and multi-cluster
expansion.

## Constraints

- OCI Always Free tier resource envelope (compute, storage, egress).
- ARM64 (Ampere A1) compatibility everywhere.
- Single maintainer initially.
- GitHub Free on a private repo — no deployment Environments, tracked as a
  known gap in `zizmor.yml` pending OCI OIDC federation (EPIC-CI-03).
- Signed, DCO-attested commits only (`CONTRIBUTING.md`).

## Non-goals (initial)

Multi-region HA, SLA-backed uptime, multi-tenant SaaS, non-OCI cloud spend,
GitHub Actions ever deploying to the cluster (Flux owns that — see
`CONTRIBUTING.md`'s ownership model).

## Success metrics

- Zero undocumented manual steps between `tofu apply` and a green Flux
  reconciliation.
- Demonstrated backup → restore RTO/RPO (I19).
- Zero secrets ever committed to git history (gitleaks-enforced already).
- Steady-state resource consumption stays inside the Free Tier envelope.

## Architectural, security, and operational principles

Infrastructure as Code, GitOps-driven, zero-trust oriented, declarative,
immutable where practical, reproducible, deterministic, auditable, secure by
default. Technology ownership boundaries are fixed and documented in
`CONTRIBUTING.md`: OpenTofu owns OCI infrastructure, Terragrunt owns
environment composition and state boundaries, Talos owns node
configuration, Flux owns Kubernetes desired state, Cilium/SPIRE/OpenBao/ESO/
Kyverno own their respective control planes, and GitHub Actions validates
and plans only — it never deploys.

See [roadmap.md](roadmap.md) for how this vision decomposes into initiatives
and milestones, and [docs/specs/README.md](../specs/README.md) for how each
capability becomes an implementable, agent-ready contract.
