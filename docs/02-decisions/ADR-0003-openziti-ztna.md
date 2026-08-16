# ADR-0003: OpenZiti for zero-trust administrative access

Status: Accepted

## Context

`docs/arch/cloud-deployment.mmd` already draws a public OpenZiti edge router
in the Edge subnet and a private OpenZiti router in the Management subnet
fronting `kube-apiserver` — the Kubernetes API has no direct public-internet
path in the diagram at all; the only route in is through Ziti's identity-aware
fabric. This is a security-load-bearing decision, not a preference, so it is
recorded rather than left implicit.

## Decision

OpenZiti is the platform's zero-trust network access layer for
administrative and control-plane access. The Kubernetes API server is never
assigned a public IP or exposed through the Internet Gateway; the only path
to it is: administrator → Ziti public edge router (Edge subnet) → Ziti
fabric → Ziti private router (Management subnet) → `kube-apiserver`.

## Consequences

- REQ-NET-003/REQ-NET-019 (see `docs/specs/SPEC-NET-001.md`,
  `SPEC-NET-004.md`) enforce "no public IP, no direct ingress to 6443" at
  the network layer independently of Ziti being correctly configured —
  defense in depth, not reliance on ZTNA alone.
- I10 (human identity/OIDC) binds administrator authentication to Ziti
  identity enrollment (EPIC-IDP-03), not to a separate bastion or VPN.
- Application ingress (end users) is a *separate* path through the Edge
  subnet's ingress NSG — Ziti is for administrative/control-plane access
  only, not general application traffic.
