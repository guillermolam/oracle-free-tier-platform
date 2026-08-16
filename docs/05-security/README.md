# Security architecture

Vulnerability reporting and handling times are defined in
[`SECURITY.md`](../../SECURITY.md) at the repo root — this directory holds
security *architecture* documentation, not the reporting policy.

## Planned contents

| Doc | Populated when |
|---|---|
| `secrets-architecture.md` | I11 (OpenBao, External Secrets Operator, PKI) |
| `pki-and-cert-lifecycle.md` | I11 EPIC-SEC-03 |
| `supply-chain.md` | I18 (image signing, SBOM) |
| `network-trust-boundaries.md` | mirrors [`docs/03-threat-model/trust-boundaries.md`](../03-threat-model/README.md) once EPIC-TM-01 lands |

Until then, the authoritative security controls already live and enforced
today are: `gitleaks` (secret scanning), `semgrep` (SAST), `zizmor`
(workflow lint), `trivy` (vuln/IaC/secret scan) — all in
[`.github/workflows/security.yml`](../../.github/workflows/security.yml) —
plus the DCO/GPG commit-signing requirement in `CONTRIBUTING.md`.
