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

This corpus sits **above** DFD notation, not inside it. A `component` is an
architecture-level fact ("this OCI Internet Gateway exists, here"); a DFD
`process`/`data store`/`external entity` is a *projection* of that fact at
a specific diagram level. Mermaid DFDs are themselves a further projection
of this corpus, the same relationship `docs/01-architecture/traceability.md`
already establishes between Specs and architecture diagrams.

## v2 — schema-hardening pass (schema_version 2.0.0)

v1 was DFD-shaped: everything that wasn't a person or an identity was a
`process`, `protocol`/`port` were flat strings, `authentication`/
`authorization` were single enum values, and undecided details were
recorded as human-readable strings inside otherwise-typed fields. That was
fine for a proof of concept but too lossy for what this corpus must
eventually drive: policies, credentials, and an IAM/PAM/RBAC/JIT/JEA graph.
v2 is a breaking change (see "Versioning" below) made deliberately early,
while only `network.yaml` existed, rather than after five more domains
were built against v1.

### BEFORE (v1) / AFTER (v2)

**Component/resource** — infrastructure no longer masquerades as a DFD process:

```yaml
# BEFORE
processes:
  - id: PROC-INTERNET-GATEWAY
    name: Internet Gateway
    trust_zone_ref: ARCH-NET-VCN
    evidence: [...]

# AFTER
components:
  - id: COMP-INTERNET-GATEWAY
    name: Internet Gateway
    component_type: network-gateway
    trust_zone_ref: ARCH-NET-VCN
    state: specified
    evidence: [...]
```

**Identity** — element `state` is now separate from evidence maturity:

```yaml
# BEFORE
identities:
  - id: IDENT-ZITI-ADMIN
    system: openziti
    evidence:
      - { source_type: adr, ref: ADR-0003, status: specified }
      - { source_type: roadmap, ref: "roadmap.md#I08", status: planned }
    # no way to say what the IDENTITY's own state is —
    # is it specified, or planned? ambiguous.

# AFTER
identities:
  - id: IDENT-ZITI-ADMIN
    system: openziti
    state: planned   # <- curated, explicit, not derived from evidence
    evidence:
      - { source_type: adr, ref: ADR-0003, status: specified }
      - { source_type: roadmap, ref: "roadmap.md#I08", status: planned }
```

**Credential** — a first-class entity, not folded into a generic asset:

```yaml
# BEFORE
# (no such thing — asset_type: credential was as specific as it got)

# AFTER
credentials:
  - id: CRED-K8S-API-CREDENTIAL
    credential_type: other   # genuinely undecided — see gaps[]
    subject_identity_ref: IDENT-ZITI-ADMIN
    state: decision-pending
    evidence: [...]
```

**Policy** — WHO, through WHICH identity, evaluated by WHICH engine, for WHICH action:

```yaml
# BEFORE
# (no such thing — authorization: kubernetes-rbac was the entire model)

# AFTER
policies:
  - id: POLICY-CONTROL-NSG-6443
    policy_type: oci-nsg-rule
    resource_refs: ["COMP-KUBE-APISERVER"]
    actions: ["ingress:tcp:6443"]
    scope_ref: COMP-CONTROL-NSG
    effect: allow
    state: specified
    evidence: [...]
```

**Flow authentication/authorization** — structured, multi-mechanism, not a lossy single enum:

```yaml
# BEFORE
authentication: mtls
authorization: nsg-security-list

# AFTER
authentication:
  required: true
  mechanisms:
    - { type: openziti-identity, identity_ref: IDENT-ZITI-ADMIN, authority_ref: COMP-ZITI-PUBLIC-ROUTER, state: planned }
    - { type: mtls, state: planned }
authorization:
  required: true
  mechanisms:
    - { type: nsg-security-list, authority_ref: COMP-CONTROL-NSG, policy_refs: [POLICY-CONTROL-NSG-6443], state: specified }
```

**Gap/unknown** — a first-class record, not prose inside a typed field:

```yaml
# BEFORE
data_flows:
  - id: FLOW-INTERNET-TO-IGW
    port: "undecided — ingress technology/application ports not yet chosen (...)"

# AFTER
data_flows:
  - id: FLOW-INTERNET-TO-IGW
    transport: { network_protocol: unknown, ports: [], state: decision-pending }
    state: decision-pending
gaps:
  - id: GAP-NET-001
    subject_ref: FLOW-INTERNET-TO-IGW
    field: "transport.ports"
    reason: "Edge-zone ingress technology has not been selected. No SPIKE currently tracks this decision."
    blocking: false
    evidence: [...]
```

**Trust boundary** — containment is no longer conflated with a two-sided crossing:

```yaml
# BEFORE
trust_boundaries:
  - id: ARCH-NET-VCN
    separates: ["ARCH-OCI-COMPARTMENT", "ARCH-ZONE-EDGE", "ARCH-ZONE-MGMT", "ARCH-ZONE-WORKLOAD", "ARCH-ZONE-DATA"]
    # this is containment (VCN CONTAINS 4 zones), not a crossing —
    # a downstream attack-path generator could infer 5 false "boundary crossings" here

# AFTER
scopes:
  - id: ARCH-NET-VCN
    scope_type: network-perimeter
    parent_ref: ARCH-OCI-COMPARTMENT   # <- containment lives here
trust_zones:
  - id: ARCH-ZONE-EDGE
    parent_ref: ARCH-NET-VCN            # <- containment, not a boundary
trust_boundaries:
  - id: TB-INTERNET-EDGE
    side_a_refs: ["EXTERNAL"]           # <- a genuine two-sided crossing
    side_b_refs: ["ARCH-ZONE-EDGE"]
```

`TB-ZONE-ISOLATION` (a v1 boundary claiming all four zones were mutually
"separated") was removed entirely rather than fixed — zone-to-zone
crossings are already inferable from a flow's `source_ref`/`destination_ref`
zone membership; a separate abstract boundary object added nothing and
risked implying pairwise crossings that were never modeled precisely.

## Element types

`scopes` (containment: tenancy → compartment → VCN, via `parent_ref`),
`trust_zones` (also carry `parent_ref` into `scopes`), `trust_boundaries`
(genuine two-sided crossings only: `side_a_refs`/`side_b_refs`), `actors`,
`identities` (see
[identity-reconciliation.md](../../01-architecture/identity-reconciliation.md)
for why a GitHub identity, an OCI IAM principal, and a Kubernetes
ServiceAccount are not assumed to be the same principal), `credentials`,
`components` (standing infrastructure/platform resources — see
`component_type` enum in the schema), `processes` (reserved for
DFD-projection-time process nodes; not populated directly in v2 — see the
schema's own description on `processes[].description`), `data_stores`,
`assets`, `data_flows`, `policies`, `controls`, `gaps`.

## `state` vs `evidence[].status` — read this before editing any file

These answer different questions and must never be conflated:

- **`evidence[].status`**: what maturity does *this one source* assert?
  Multiple evidence entries on the same element can (and often do) assert
  different maturities — an ADR might be `specified` while the roadmap
  initiative implementing it is only `planned`.
- **`state`**: what is the element's own curated, effective state? Set
  explicitly by whoever populates the corpus, **never derived
  automatically** from the strongest or weakest evidence entry. A
  `PROC-ZITI-PRIVATE-ROUTER`-style component can be `state: planned` even
  while one of its evidence entries is `status: specified` — the ADR
  decision is specified, but the component itself (its actual
  configuration) is still only planned.

Values: `implemented | specified | planned | candidate | decision-pending`
(plus reserved-for-later `deprecated | retired`). `implemented` means
actually running (`infrastructure/` applied) — nothing in this repo
qualifies yet, it's greenfield. The validator enforces that any element
claiming `state: implemented` has at least one evidence entry that also
says `implemented` — state can't outrun what any source actually asserts.

## ID conventions

- **Reuse, don't duplicate**: where a corpus element is a genuine 1:1
  match for an existing stable concept, its `id` **is** that concept's
  ID — `trust_zones[].id` is always an `ARCH-ZONE-*` ID, `scopes[].id`
  reuses `ARCH-OCI-*`/`ARCH-NET-*` where one exists. This is a hard
  requirement — a duplicate ID for the same concept is exactly the drift
  this corpus exists to prevent.
- **Mint + cite**: everything else gets a new type-prefixed ID and cites
  any related `ARCH-*` concept through an `evidence` entry instead:
  `ACTOR-`, `IDENT-`, `CRED-`, `COMP-`, `PROC-`, `DS-`, `ASSET-`, `FLOW-`,
  `POLICY-`, `CTRL-`, `GAP-`, `SCOPE-` (fallback for a scope with no
  matching `ARCH-*` concept).

## Versioning

`schema_version` (const, e.g. `"2.0.0"`) binds an instance file to the
exact schema generation that validated it — independent of `model_version`
(semver for the instance's own content). A schema change that isn't purely
additive must bump `schema_version` and migrate every instance file before
they can declare the new version; this repo makes that change immediately
while only one instance exists rather than deferring it.

## Validation

```sh
npm run test:threat-model       # validator self-test (fixtures, no real corpus data)
npm run validate:threat-model   # schema + corpus-wide invariants against instances/*.yaml
```

`validate-threat-model.mjs` checks, beyond JSON Schema: no duplicate IDs
across files; every `*_ref` resolves to a real corpus ID, a known `ARCH-*`
concept read live from `traceability.md`, or `EXTERNAL`; no two identities'
`maps_to` entries disagree about `same_principal` for the same pair; every
`state: implemented` element has `>=1` evidence entry with
`status: implemented`; every `state: decision-pending` element has a
`gaps[]` entry naming it (top-level element state only — a nested
`transport.state`/mechanism `state` of `decision-pending` is not required
to have its own `gaps[]` entry, though adding one is still good practice).
See the script's header comment for its one remaining documented
limitation: ref resolution checks existence, not type.

## Status

All six domains are now populated: `network.yaml` (schema v2 proof of
concept), plus `context`, `identity`, `governance`, `cicd`, and
`kubernetes`, added once the schema proved ready to scale. The corpus
validates together (`npm run validate:threat-model`) with zero schema or
referential-integrity failures. See `docs/03-threat-model/README.md` for
where this fits in the overall threat-modeling sequence — DFD generation
(Phase 3A's remaining step) is next, not started here.
