# Supply chain posture

The current M1-M4 bootstrap path intentionally uses upstream official Helm
repositories and OCI-hosted artifacts directly.

## Current state

- Flux consumes upstream Helm and OCI sources with exact chart version pins.
- No component in M1-M4 requires a source build to install or reconcile.
- This repository does not yet mirror upstream charts or images into an
  internal registry.
- This repository does not yet generate SLSA provenance for the platform
  controllers it installs.

## Why this is acceptable now

The immediate goal is to establish the bootstrap control plane:

- Flux as the sole GitOps reconciler
- cert-manager for certificate lifecycle
- Dex for shared human OIDC
- OpenZiti control-plane integration
- SPIRE for workload identity
- OpenBao and ESO for secret delivery

Requiring source builds before these controllers can even exist would stall
M1-M4 on supply-chain work that belongs to a later hardening milestone.

## Deferred SLSA path

The future supply-chain milestone should raise the posture to at least SLSA
L2 for the first-wave identity and security controllers:

- Dex
- OpenBao
- SPIRE
- External Secrets Operator
- OpenZiti
- Argo CD

That later phase should add:

- source-based builds
- SBOM generation
- provenance attestation
- immutable internal registry publication
- signature verification and policy gates preferring attested artifacts

Until then, version pinning plus render validation is the deliberate
bootstrap baseline.
