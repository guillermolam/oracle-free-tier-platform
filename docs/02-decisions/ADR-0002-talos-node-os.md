# ADR-0002: Talos as the node operating system

Status: Accepted

## Context

`CONTRIBUTING.md` already states "Talos owns node configuration", and
`docs/arch/cloud-deployment.mmd` depicts Talos control-plane and worker
nodes directly. Node OS choice is foundational to I04 (Compute & Talos
Foundation) and I06 (Container Runtime) and needs to be recorded before
those initiatives implement against it.

## Decision

All Kubernetes nodes (control plane and workers) run Talos Linux. Talos owns
node-level configuration and lifecycle (immutable, API-managed, no SSH) —
node config is generated and applied declaratively, never edited in place.
`CODEOWNERS` reserves `bootstrap/talos/` for `@guillermolam` review.

## Consequences

- No SSH access to nodes; all node operations go through the Talos API
  (`talosctl`) or are encoded in machine config applied at boot.
- Container runtime is whatever Talos bakes in (containerd) unless
  SPIKE-RT-01 (youki compatibility) changes that — see I06.
- ARM64 (Ampere A1) support must be verified for the specific Talos release
  pinned by SPEC-COMP-* before it's adopted (SPIKE-COMP-01 territory).
- Node upgrades are a Talos API operation, tracked as a day-2 runbook under
  I24 once the cluster exists.
