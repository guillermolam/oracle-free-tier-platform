# Security architecture

Vulnerability reporting and handling times are defined in
[`SECURITY.md`](../../SECURITY.md) at the repo root — this directory holds
security *architecture* documentation, not the reporting policy.

## Planned contents

| Doc | Populated when |
| --- | --- |
| `secrets-architecture.md` | landed with the first M4 bootstrap secret flow |
| `pki-and-cert-lifecycle.md` | I11 EPIC-SEC-03 |
| `supply-chain.md` | current upstream-artifact baseline plus deferred SLSA path |
| `network-trust-boundaries.md` | mirrors the future `trust-boundaries.md` described in [`docs/03-threat-model/README.md`](../03-threat-model/README.md) once EPIC-TM-01 lands |

Until then, the authoritative security controls already live and enforced
today are: `gitleaks` (secret scanning), `semgrep` (SAST), `zizmor`
(workflow lint), `trivy` (vuln/IaC/secret scan) — all in
[`.github/workflows/security.yml`](../../.github/workflows/security.yml) —
plus the DCO/GPG commit-signing requirement in `CONTRIBUTING.md`.
