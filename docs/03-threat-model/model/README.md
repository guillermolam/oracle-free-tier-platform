# Threat-model normalized corpus

A machine-readable, schema-validated representation of the architecture,
normalized once from the 26 Mermaid views + Specs + ADRs so that every
downstream artifact (DFDs, STRIDE/LINDDUN analysis, attack trees, MITRE
ATT&CK mapping, IriusRisk reconciliation, the IAM/PAM/RBAC/JIT/JEA
authorization graph) is generated **from this corpus**, not by
re-interpreting the architecture documentation from scratch each time.

```text
docs/01-architecture/**/*.mmd, docs/specs/*.md, docs/02-decisions/*.md
             │  (normalized once, by hand, evidence-checked)
             ▼
docs/03-threat-model/model/instances/*.yaml   <- THIS is the source of truth
   (validated against schema/threat-model.schema.json)
             │
             ▼
DFD L0-L3, STRIDE/LINDDUN, attack trees, MITRE mapping, IriusRisk, IAM/PAM
```

Mermaid becomes a **projection** of this model for DFDs, the same
relationship `docs/01-architecture/traceability.md` already establishes
between Specs and architecture diagrams.

## Why this exists

Without a normalized intermediate model, generating a DFD or an attack tree
requires re-reading and re-interpreting 26 Mermaid files plus a dozen Specs
and ADRs every time — a process with no determinism guarantee. Two
generation passes over the same architecture could produce different trust
boundaries, different flow lists, or a different IAM graph, and nothing
would catch the drift. This corpus exists to make that reinterpretation
happen exactly once, in a structured, schema-validated, evidence-checked
form that every later phase reads instead of the raw architecture docs.

## Layout

- `schema/threat-model.schema.json` — versioned JSON Schema (draft
  2020-12), the contract every instance file must satisfy.
- `instances/<domain>.yaml` — one file per architecture domain, mirroring
  `docs/01-architecture/<domain>/`: `context`, `network`, `identity`,
  `governance`, `cicd`, `kubernetes`.

## Element types

`trust_zones`, `trust_boundaries`, `actors`, `identities`, `processes`,
`data_stores`, `assets`, `data_flows` — the standard DFD/STRIDE element set,
plus `identities` (distinct from `actors` — see
[identity-reconciliation.md](../../01-architecture/identity-reconciliation.md)
for why a GitHub identity, an OCI IAM principal, and a Kubernetes
ServiceAccount are not assumed to be the same principal) and `assets` (for
confidentiality/integrity/availability requirements independent of any
single flow).

## ID conventions

- **Reuse, don't duplicate**: where a corpus element is a genuine 1:1 match
  for an existing stable concept, its `id` **is** that concept's ID —
  `trust_zones[].id` is always an `ARCH-ZONE-*` ID, and
  `trust_boundaries[].id` is an `ARCH-OCI-*`/`ARCH-NET-*` ID where one
  already exists (falling back to a new `TB-*` ID otherwise). This is a
  hard requirement, not a convention to relax under time pressure — a
  duplicate ID for the same concept is exactly the drift this corpus
  exists to prevent.
- **Mint + cite**: `actors`, `identities`, `processes`, `data_stores`,
  `assets`, and `data_flows` don't generally have a pre-existing ARCH-* ID
  (they're finer-grained than the architecture vocabulary), so they get a
  new type-prefixed ID (`ACTOR-`, `IDENT-`, `PROC-`, `DS-`, `ASSET-`,
  `FLOW-`) and cite any related `ARCH-*` concept through an `evidence`
  entry (`source_type: arch-view`) instead.

## Evidence discipline

Every element requires `evidence: [...]` with at least one entry — the
same rule `docs/01-architecture/traceability.md` enforces for diagrams,
applied to this corpus. `evidence[].status` is one of:

| Status | Meaning |
| --- | --- |
| `implemented` | Actually running (`infrastructure/` applied). None of this repo yet — it's greenfield. |
| `specified` | An approved (Ready/Accepted) Spec or ADR covers it, not yet built. |
| `planned` | Named in `roadmap.md`, no Spec yet. |
| `candidate` | Plausible but not confirmed anywhere — flag, don't assert. |
| `decision-pending` | Tied to an open SPIKE or an explicitly-marked open decision point in a view. |

A `port`, `protocol`, or other field that is genuinely undecided in the
architecture (e.g. Edge-zone ingress technology) is recorded as an
explicit string describing the gap (`"undecided — ..."`), never a plausible
guess. This mirrors `edge-zone.mmd`'s own practice of marking that decision
open rather than inventing an ingress technology.

## Validation

```sh
npm run validate:threat-model
```

Validates every `instances/*.yaml` against the schema, then checks
corpus-wide referential integrity: no duplicate IDs across files, and every
`*_ref` field resolves to a real corpus ID, a known `ARCH-*` concept (read
live from `traceability.md`, not a separately-maintained copy that could
drift), or the literal `EXTERNAL`. See the script's header comment
(`scripts/validate-threat-model.mjs`) for its one documented limitation:
ref resolution checks existence, not type.

## Status

`network.yaml` is the only populated instance so far — a proof of concept
for the schema and tooling before scaling to the remaining five domains.
See `docs/03-threat-model/README.md` for where this fits in the overall
threat-modeling sequence.
