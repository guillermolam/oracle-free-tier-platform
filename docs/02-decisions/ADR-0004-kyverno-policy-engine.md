# ADR-0004: Kyverno as the admission policy engine

Status: Accepted

## Context

`CONTRIBUTING.md`'s ownership model names Kyverno explicitly alongside
Cilium/SPIRE/OpenBao/ESO as owning its control plane. This ADR exists to
make that choice discoverable outside of `CONTRIBUTING.md` and to close off
re-litigating OPA/Gatekeeper vs. Kyverno as an open spike — it isn't one.

## Decision

Kyverno is the platform's Kubernetes admission policy engine. It owns
policy enforcement for: prohibiting public IPs at the workload level,
image signature verification (I18, `cosign` + Kyverno `verifyImages`),
resource quotas, and any other admission-time governance rule. Policies are
reconciled by Flux like any other cluster desired state (ADR-0005) — Kyverno
`ClusterPolicy`/`Policy` resources live under `platform/`, not applied
imperatively.

## Consequences

- I14's baseline policy set (EPIC-POL-02) is written in Kyverno's native
  policy CRDs, not Rego/OPA.
- Policy exceptions go through EPIC-POL-03's reporting/exception workflow,
  not ad hoc `kubectl` overrides.
- OPA/Gatekeeper is out of scope; reopening this requires a superseding ADR
  with an explicit reason, not a default re-evaluation.
