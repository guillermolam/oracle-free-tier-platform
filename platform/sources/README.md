# Upstream source policy

M1-M4 bootstrap uses upstream official Helm repositories and OCI-hosted
charts/images directly. No OCIR/Cloudflare mirroring is required yet.

## Pinned sources

| Component | Source kind | Upstream | Pinned version | App version | Notes |
| --- | --- | --- | --- | --- | --- |
| Flux bootstrap | generated manifest | `flux install --export` | `v2.9.4` | controller images from Flux bootstrap manifest | committed output, not chart-managed |
| Argo CD | `HelmRepository` | `https://argoproj.github.io/argo-helm` | `10.4.0` | `v3.5.1` | Flux-managed workload, not platform owner |
| cert-manager | `OCIRepository` | `oci://quay.io/jetstack/charts/cert-manager` | `v1.21.1` | `v1.21.1` | OCI-native chart via Flux `OCIRepository` |
| Dex | `HelmRepository` | `https://charts.dexidp.io` | `0.24.1` | `2.44.0` | shared human OIDC issuer |
| External Secrets Operator | `HelmRepository` | `https://charts.external-secrets.io` | `2.9.0` | `v2.9.0` | namespaced `SecretStore` posture |
| OpenBao | `HelmRepository` | `https://openbao.github.io/openbao-helm` | `0.29.2` | `v2.6.2` | bootstrap TLS Secret wired in |
| SPIRE | `HelmRepository` | `https://spiffe.github.io/helm-charts-hardened/` | `0.30.0` | `1.14.5` | main stack chart |
| SPIRE CRDs | `HelmRepository` | `https://spiffe.github.io/helm-charts-hardened/` | `0.6.0` | n/a | separate CRD chart upstream |
| OpenZiti controller | `HelmRepository` | `https://docs.openziti.io/helm-charts/` | `3.2.1` | `2.0.1` | controller only for now |
| OpenZiti router | source pinned only | `https://docs.openziti.io/helm-charts/` | `3.0.1` | `2.0.1` | topology/release placement remains M3 work |

## Current digest posture

- Chart versions are pinned everywhere.
- cert-manager's upstream chart OCI digest is known at validation time, but
  component image digests are not yet overridden in the release values.
- Dex, Argo CD, ESO, OpenBao, SPIRE, and OpenZiti charts expose image
  override knobs, but this bootstrap phase does not yet lock all controller
  image digests in Git.

That digest gap is intentional for M1-M4. The future supply-chain milestone
is where this repo should add source builds or curated internal mirrors, SBOMs,
provenance, signatures, and SLSA-oriented policy enforcement.
