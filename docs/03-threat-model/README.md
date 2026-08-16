# Threat model

Status: not started — EPIC-TM-01 (I20) is Ready but not yet implemented.

## Evidence chain

Security architecture evolves alongside implementation, not after it. Each
Spec that changes a trust boundary must state its Threat Model Impact
(`docs/specs/README.md` template) and this directory is updated in the same
PR, following:

```text
Evidence -> Facts -> Architecture Graph -> DFD -> Trust Boundaries
  -> Assets -> Threats -> Weaknesses -> Attack Paths -> Risk -> Controls
  -> Residual Risk
```

Nothing here may be invented ahead of evidence — no architecture, asset,
threat, or control is recorded without a corresponding Spec, ADR, or
diagram backing it.

## First artifact (EPIC-TM-01)

A DFD L0/L1 derived directly from
[`docs/arch/cloud-deployment.mmd`](../arch/cloud-deployment.mmd) and
[ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md)'s
four trust zones (Edge / Management / Workload / Data). `SPEC-NET-004.md`
(Security Lists + NSGs) is the first Spec expected to feed this directly —
its Threat Model Impact section names the trust boundaries it establishes.

## Structure (once populated)

- `dfd-l0.md` — system context.
- `dfd-l1.md` — trust-zone-level data flows.
- `trust-boundaries.md` — the boundary list ADR-0006 establishes.
- `threats.md` — STRIDE inventory per boundary.
- `attack-paths.md` — validated attack paths, not hypothetical ones.
- `risk-register.md` — risk, control, residual risk per threat.
