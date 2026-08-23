# ADR-0010: Crossplane remains outside the bootstrap path

Status: Accepted

## Context

The platform roadmap already fixes ownership boundaries:

- OpenTofu + Terragrunt own OCI infrastructure lifecycle.
- Flux owns Kubernetes desired state.
- Argo CD may exist in-cluster, but it cannot supersede Flux as the platform
  reconciler without overturning ADR-0005.

The current ecosystem evidence reinforces that split:

- Crossplane's own guidance presents Argo CD and Crossplane as
  complementary, not as a replacement for cluster/bootstrap IaC.
- `crossplane-contrib/provider-argocd` manages Argo CD objects through
  Crossplane; it does not bootstrap Argo CD, Flux, or the underlying cloud.
- Upjet accelerates provider generation, but generated providers still become
  Kubernetes control-plane dependencies that themselves need a working
  cluster, GitOps path, credentials, and RBAC.

## Decision

Crossplane is deferred for this platform's bootstrap and M1-M4 control-plane
foundation. OpenTofu + Terragrunt remain the source of truth for OCI and
other external infrastructure, while Flux remains the sole GitOps
reconciler for Kubernetes desired state.

Argo CD may be installed as a Flux-managed workload for later multi-cluster
or application-delivery use cases, but it does not become a second owner of
`platform/`.

`provider-argocd`, other Crossplane providers, and Upjet-generated control
planes are treated as later optional workload-level capabilities, not as a
replacement for the bootstrap path.

## Consequences

- M1-M4 can proceed without introducing a second infrastructure control
  plane.
- The repo may install Argo CD, but Argo CD must be reconciled by Flux and
  constrained to non-platform ownership boundaries.
- Any future adoption of Crossplane requires a separate Spec/ADR covering
  credentials, RBAC scope, reconciliation ownership, and failure domains.
