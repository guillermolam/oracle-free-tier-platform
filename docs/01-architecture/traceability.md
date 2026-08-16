# Architecture traceability

`docs/arch/cloud-deployment.mmd` and every file under
`docs/01-architecture/{context,network}/` are visualizations. Their Mermaid
node/group/junction IDs are implementation details of *that rendering* —
free to be renamed, collapsed, expanded, or replaced entirely whenever a
diagram is redrawn for clarity. `cloud-deployment.mmd` has already been
reworked once (see Status below). If Specs cited those IDs directly as
normative, every diagram simplification would silently break
specification traceability.

Instead, a Spec's **Diagram Impact** section cites a stable **architecture
concept ID** (`ARCH-*`, this file) plus the governing view — never a
Mermaid node name:

```text
SPEC-NET-005
    │
    ├── ARCH-FLOW-INGRESS
    ├── ARCH-FLOW-EGRESS
    ├── ARCH-FLOW-SERVICE
    └── ARCH-FLOW-HYBRID
              │
              ▼
      docs/01-architecture/network/traffic-flows.mmd  (see views.md)
              │
              ▼
        Mermaid nodes/edges
```

The diagram can rename `workers ×2` to `worker-pool`, split `gateways`
back into four components, or be replaced by an entirely different
renderer, without a single Spec needing to change. This file is the fixed
point the diagrams are redrawn *against*, not the other way around.

## Mermaid validation authority

```text
Source .mmd
     │
     ▼
Mermaid CLI (mmdc)
     │
     ├── PASS → syntactically valid architecture artifact
     │
     └── FAIL → invalid architecture artifact, must be fixed before merge

Editor Preview (VS Code Mermaid extensions, etc.)
     │
     └── non-authoritative convenience renderer — never the merge gate
```

`mmdc` is the authority. An editor preview reporting an error on syntax
`mmdc` accepts is an editor limitation, not a reason to rewrite valid
Mermaid.

**Pinned version:** `@mermaid-js/mermaid-cli@11.16.0` — `package.json`
devDependency, enforced by the `mermaid` job in `docs.yml` (`npm ci &&
npm run validate:mermaid`, walking every `.mmd` file under `docs/`). A
Mermaid syntax regression now fails CI the same way a Markdown lint
regression does.

## Vocabulary

Each concept lists its **Primary View** (where it's introduced/most
legible) and **Detail View** (where it's elaborated), per the view catalog
in [`views.md`](views.md).

### OCI structural boundaries

| ID | Meaning | Primary View | Detail View |
| --- | --- | --- | --- |
| `ARCH-OCI-TENANCY` | The OCI tenancy as the outermost structural boundary. | VIEW-NET-OVERVIEW | — |
| `ARCH-OCI-COMPARTMENT` | The platform compartment isolating platform resources from the tenancy root. | VIEW-NET-OVERVIEW | — |
| `ARCH-GOV-TENANCY` | Tenancy-level IAM, policies, dynamic groups, defined tags, audit — the governance *process*, distinct from the structural boundaries above. | VIEW-CLOUD-DEPLOYMENT | — |

### Network core

| ID | Meaning | Primary View | Detail View |
| --- | --- | --- | --- |
| `ARCH-NET-VCN` | The platform VCN (`10.10.0.0/16`) as a security perimeter. | VIEW-NET-OVERVIEW | VIEW-NET-ROUTING |
| `ARCH-NET-DNS` | VCN-scoped DNS resolution and DHCP options. | VIEW-CLOUD-DEPLOYMENT | — |

### Trust zones

| ID | Meaning | Primary View | Detail View |
| --- | --- | --- | --- |
| `ARCH-ZONE-EDGE` | Public-facing subnet — the only zone permitted a public IP. | VIEW-NET-OVERVIEW | VIEW-NET-EDGE |
| `ARCH-ZONE-MGMT` | Control-plane/administrative subnet — Kubernetes API, etcd, Ziti private router. | VIEW-NET-OVERVIEW | VIEW-NET-MANAGEMENT |
| `ARCH-ZONE-WORKLOAD` | Talos worker subnet. | VIEW-NET-OVERVIEW | VIEW-NET-WORKLOAD |
| `ARCH-ZONE-DATA` | Storage/backup subnet. | VIEW-NET-OVERVIEW | VIEW-NET-DATA |

### Gateways

| ID | Meaning | Primary View | Detail View |
| --- | --- | --- | --- |
| `ARCH-GW-IGW` | Internet Gateway — Edge zone's sole internet-facing ingress point. | VIEW-NET-OVERVIEW | VIEW-NET-ROUTING |
| `ARCH-GW-NAT` | NAT Gateway — private egress for Management/Workload/Data. | VIEW-NET-OVERVIEW | VIEW-NET-ROUTING |
| `ARCH-GW-SGW` | Service Gateway — private OCI service access. | VIEW-NET-OVERVIEW | VIEW-NET-ROUTING |
| `ARCH-GW-DRG` | Dynamic Routing Gateway — reserved, inert until I21 ([ADR-0008](../02-decisions/ADR-0008-drg-reserved-inert-m1.md)). | VIEW-NET-OVERVIEW | VIEW-NET-ROUTING |

### Traffic flows

| ID | Meaning | Traffic-class color | Primary View | Detail View |
| --- | --- | --- | --- | --- |
| `ARCH-FLOW-INGRESS` | Internet → Edge → application ingress | RED | VIEW-NET-TRAFFIC | VIEW-NET-EDGE |
| `ARCH-FLOW-EGRESS` | Private nodes → NAT Gateway → Internet | GREEN | VIEW-NET-TRAFFIC | VIEW-NET-ROUTING |
| `ARCH-FLOW-SERVICE` | Any zone → Service Gateway → OCI services | BLUE | VIEW-NET-TRAFFIC | VIEW-NET-ROUTING |
| `ARCH-FLOW-BACKUP` | Data-zone volumes → backup endpoint → Service Gateway | BLUE | VIEW-NET-TRAFFIC | VIEW-NET-DATA |
| `ARCH-FLOW-ADMIN` | Administrator → Ziti public edge → Ziti fabric → Ziti private router | PURPLE | VIEW-NET-TRAFFIC | VIEW-NET-EDGE, VIEW-NET-MANAGEMENT |
| `ARCH-FLOW-CONTROL` | Kubernetes API ↔ control plane ↔ worker nodes | PURPLE | VIEW-NET-TRAFFIC | VIEW-NET-MANAGEMENT, VIEW-NET-WORKLOAD |
| `ARCH-FLOW-HYBRID` | VCN → DRG → future on-prem/other-cloud (reserved, inert until I21) | ORANGE | VIEW-NET-TRAFFIC | VIEW-NET-ROUTING |

### Platform services

| ID | Meaning | Primary View | Detail View |
| --- | --- | --- | --- |
| `ARCH-SVC-KMS` | OCI Vault / KMS — encryption key management. | VIEW-CLOUD-DEPLOYMENT | — (planned: VIEW-SECRETS, I11) |
| `ARCH-SVC-LOGGING` | OCI Logging. | VIEW-CLOUD-DEPLOYMENT | — (planned: VIEW-OBSERVABILITY, I16) |
| `ARCH-SVC-MONITORING` | OCI Monitoring. | VIEW-CLOUD-DEPLOYMENT | — (planned: VIEW-OBSERVABILITY, I16) |
| `ARCH-SVC-BACKUP-BUCKET` | OCI Object Storage backup target — reserved for I19/M9, not yet specified. | VIEW-NET-DATA | — (planned: VIEW-STORAGE, I15) |

This list grows only when a Spec needs a concept it doesn't already cover.
Don't pre-mint IDs for initiatives that haven't reached specification depth
yet (see `docs/00-overview/roadmap.md`'s rolling-wave planning note and
`views.md`'s Planned views table).

## Source-of-truth chain

```text
Specs (normative)
    │
    ▼
Stable architecture concepts (ARCH-*, this file)
    │
    ▼
Architecture views (docs/01-architecture/**, see views.md)
    │
    ▼
Mermaid implementation (node IDs, groups, junctions — renderer detail)
```

A diagram MUST NOT silently introduce a requirement absent from a Spec or
ADR. If a view needs to show something not yet decided (e.g., Edge-zone
ingress technology), it marks that explicitly as an open decision point —
it does not invent an answer. See `edge-zone.mmd`, `management-zone.mmd`,
`workload-zone.mmd`, and `data-zone.mmd` for worked examples of this rule.

## DRY does not mean zero duplication

`VCN 10.10.0.0/16` legitimately appears in `cloud-deployment.mmd`,
`network-overview.mmd`, `routing.mmd`, and `traffic-flows.mmd` — each
answers a different question (full system picture, segmentation, next-hop
routing, security-relevant flow classes). The invariant enforced here is
**semantic consistency** (every view agrees on the CIDR, on which zones
allow a public IP, on which gateway serves which flow), not textual
uniqueness. Two views repeating a fact at different abstraction levels is
expected. Two views *disagreeing* about a fact is architectural drift —
that's a bug, filed against whichever view is wrong relative to the
governing Spec.

## Status of diagram artifacts

- `docs/arch/cloud-deployment.mmd` — **canonicalized** (`6b997c1`, "compact
  cloud-deployment.mmd for readability"). Renamed and collapsed many nodes
  (~170x smaller render) while preserving every CIDR, trust zone, and
  traffic-flow class this vocabulary is built from — exactly what this
  file's decoupling was designed to survive without any Spec needing to
  change. Untouched by the multi-view work described here.
- `docs/01-architecture/context/platform-context.mmd` and everything under
  `docs/01-architecture/network/` — new, committed, `mmdc`-validated views
  introduced to answer questions `cloud-deployment.mmd` was being asked to
  answer all at once. See [`views.md`](views.md) for the full catalog.
