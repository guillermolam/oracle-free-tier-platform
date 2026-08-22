# Platform manifests

`platform/` is the Kubernetes desired-state tree owned by Flux, per
[ADR-0005](../docs/02-decisions/ADR-0005-flux-gitops.md).

## Structure

```text
platform/
  clusters/lab/         # cluster entrypoint Flux reconciles
  infrastructure/       # namespaces and shared cluster plumbing
  sources/              # HelmRepository / GitRepository / OCIRepository objects
  gitops/               # platform workloads managed by Flux
```

## Current scope

- Flux bootstrap artifacts for the `lab` cluster are committed under
  `clusters/lab/flux-system/`.
- Upstream official Helm repositories and OCI registries are the current
  bootstrap source of truth for platform controllers.
- Argo CD is installed as a Flux-managed Helm release.
- Argo CD is **not** the owner of `platform/`; it is a managed workload
  inside the platform.
- cert-manager, Dex, External Secrets Operator, OpenBao, SPIRE, and the
  OpenZiti controller are modeled as Flux-managed releases in this tree.
- The OpenZiti router topology remains an M3 network-placement concern; the
  repository pins the upstream chart source now, but does not yet declare the
  edge/private router release topology in-cluster.
- Crossplane remains deferred for bootstrap and OCI infrastructure lifecycle.
  See [ADR-0010](../docs/02-decisions/ADR-0010-crossplane-bootstrap-boundary.md).
- Source builds and SLSA are deferred to a later supply-chain hardening
  milestone; see [`docs/05-security/supply-chain.md`](../docs/05-security/supply-chain.md).

## Public identity domain

The public identity issuer is `https://auth.platform.lamcloud.net`. The
Cloudflare-managed `lamcloud.net` zone is the canonical public DNS boundary
for M4; the former public domain is not used by the platform.

## Bootstrap note

Two bootstrap secrets are intentionally created out of band and are never
committed to Git:

- `flux-system/flux-system` for the Flux Git SSH deploy key
- `dex/dex-github-connector` for the GitHub OAuth client ID and secret Dex
  needs before OpenBao and ESO exist

`gotk-sync.yaml` expects the Flux Git authentication Secret for the SSH
remote:

```text
ssh://git@github.com/guillermolam/oracle-free-tier-platform.git
```

The Dex GitHub Secret follows the same bootstrap-only rule. The Dex client
used later by OpenBao OIDC is intentionally deferred until the later auth
wiring phase, after OpenBao and ESO are running.
