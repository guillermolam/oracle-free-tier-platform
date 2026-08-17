# Threat model

Status: Phase 3A in progress — EPIC-TM-01 (I20) is Ready. The pipeline
below is followed in order; each phase is a distinct, reviewed step, not a
single pass:

```text
Architecture corpus (docs/01-architecture/**, Specs, ADRs)
      |
      v
model/ — normalized, schema-validated corpus       <- Phase 3A, in progress
      |
      v
DFD L0 -> L1 -> L2/L3                               <- Phase 3A
      |
      v
4 Questions Framework -> STRIDE (+ LINDDUN)          <- Phase 3B
      |
      v
Attack Trees -> Attack Forest -> MITRE ATT&CK        <- Phase 3B
      |
      v
Risk + Controls + Residual Risk                      <- Phase 3B
      |
      v
IriusRisk validation/reconciliation                  <- Phase 3C
      |
      v
IAM/PAM authorization graph -> RBAC + JIT + JEA       <- Phase 3C
```

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

## Phase 3A: normalized model (in progress)

See [`model/README.md`](model/README.md) for the full contract. The
critical design goal: DFDs and every later phase (STRIDE, attack trees,
MITRE mapping, IriusRisk, IAM/PAM) are generated from
`model/instances/*.yaml`, not by re-interpreting the 26 Mermaid views from
scratch each time — that reinterpretation happens exactly once, here,
schema-validated and evidence-checked.

Status: schema (`model/schema/threat-model.schema.json`) and tooling
(`npm run validate:threat-model`) built and validated against one domain
(`model/instances/network.yaml`) as a proof of concept. Remaining domains
(`identity`, `governance`, `cicd`, `kubernetes`, `context`) and DFD L0-L3
generation from the corpus come next.

## First DFD artifact (EPIC-TM-01)

A DFD L0/L1 derived from the normalized corpus above (not directly from
Mermaid), covering [ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md)'s
four trust zones (Edge / Management / Workload / Data). `SPEC-NET-004.md`
(Security Lists + NSGs) is the first Spec feeding this directly — its
Threat Model Impact section names the trust boundaries it establishes.

## Structure (once populated)

- `model/` — Phase 3A normalized corpus (schema + instances).
- `dfd-l0.md` — system context.
- `dfd-l1.md` — trust-zone-level data flows.
- `dfd-l2-l3.md` — component/zone-detail flows.
- `trust-boundaries.md` — the boundary list ADR-0006 establishes.
- `threats.md` — STRIDE (+ LINDDUN) inventory per boundary — Phase 3B.
- `attack-trees.md`, `attack-forest.md` — Phase 3B.
- `mitre-attack-mapping.md` — Phase 3B.
- `attack-paths.md` — validated attack paths, not hypothetical ones — Phase 3B.
- `risk-register.md` — risk, control, residual risk per threat — Phase 3B.
- `iriusrisk-reconciliation.md` — Phase 3C.
- `iam-pam-graph.md` — RBAC/JIT/JEA derivation — Phase 3C.
