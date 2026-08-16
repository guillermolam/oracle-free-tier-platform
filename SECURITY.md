# Security Policy

This project deploys a Kubernetes platform on Oracle Cloud Infrastructure (OCI). It
handles infrastructure-as-code, node configuration, and GitOps manifests. Cloud
credentials and cluster material are sensitive.

## Supported versions

Only the current state of the `main` branch is supported. There are no LTS
releases at this time.

## Reporting a vulnerability

This repository is private and owned by a single maintainer. If you have access
and found a security issue:

1. Do **not** open a public issue or commit details to `main`.
2. Open a private report using the GitHub Security Advisories flow, or open an
   issue using the `Security` template and add the `risk/critical` label.
3. If credentials or cluster secrets are involved, treat them as compromised and
   rotate them before reporting.

Expected handling times:

- **Critical / High**: acknowledged within 24 h, remediation goal within 7 days.
- **Medium / Low**: acknowledged within 72 h, remediation goal within 30 days.

## Security expectations

- No OCI API keys, `.oci/` material, Talos secrets, kubeconfigs, `.env` files, or
  unencrypted SOPS files are ever committed.
- All commits are signed and verified.
- Secrets in the repository are encrypted with SOPS; decrypted material is never
  committed.
- GitHub Actions never deploy Kubernetes. They validate and produce plans only;
  Flux reconciles the cluster.
