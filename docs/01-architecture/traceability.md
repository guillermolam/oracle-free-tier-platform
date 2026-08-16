# Architecture traceability

`docs/arch/cloud-deployment.mmd` is a visualization. Its Mermaid node/group/
junction IDs (`w1Node`, `zitiEdge`, `cpVNIC`, ...) are implementation
details of *that rendering* — free to be renamed, collapsed, expanded, or
replaced entirely whenever the diagram is redrawn for clarity. It has
already been reworked once (see Status below). If Specs cited those IDs
directly as normative, every diagram simplification would silently break
specification traceability.

Instead, a Spec's **Diagram Impact** section cites a stable **architecture
concept ID** (`ARCH-*`, this file) plus the artifact path — never a
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
docs/arch/cloud-deployment.mmd
              │
              ▼
    Mermaid nodes/edges
```

The diagram can rename `workers ×2` to `worker-pool`, split `gateways`
back into four components, or be replaced by an entirely different
renderer, without a single Spec needing to change. This file is the fixed
point the diagram is redrawn *against*, not the other way around.

## Vocabulary

### Network core

| ID | Meaning |
| --- | --- |
| `ARCH-NET-VCN` | The platform VCN (`10.10.0.0/16`) as a security perimeter. |
| `ARCH-NET-DNS` | VCN-scoped DNS resolution and DHCP options. |

### Trust zones

| ID | Meaning |
| --- | --- |
| `ARCH-ZONE-EDGE` | Public-facing subnet — the only zone permitted a public IP. |
| `ARCH-ZONE-MGMT` | Control-plane/administrative subnet — Kubernetes API, etcd, Ziti private router. |
| `ARCH-ZONE-WORKLOAD` | Talos worker subnet. |
| `ARCH-ZONE-DATA` | Storage/backup subnet. |

### Traffic flows

| ID | Meaning | Traffic-class color |
| --- | --- | --- |
| `ARCH-FLOW-INGRESS` | Internet → Edge → application ingress | RED |
| `ARCH-FLOW-EGRESS` | Private nodes → NAT Gateway → Internet | GREEN |
| `ARCH-FLOW-SERVICE` | Private resources → Service Gateway → OCI services | BLUE |
| `ARCH-FLOW-BACKUP` | Data-zone volumes → backup endpoint → Service Gateway | BLUE |
| `ARCH-FLOW-ADMIN` | Administrator → Ziti public edge → Ziti fabric → Ziti private router | PURPLE |
| `ARCH-FLOW-CONTROL` | Kubernetes API ↔ control plane ↔ worker nodes | PURPLE |
| `ARCH-FLOW-HYBRID` | VCN → DRG → future on-prem/other-cloud — reserved, inert until I21 ([ADR-0008](../02-decisions/ADR-0008-drg-reserved-inert-m1.md)) | ORANGE |

### Governance

| ID | Meaning |
| --- | --- |
| `ARCH-GOV-TENANCY` | Tenancy-level IAM, policies, dynamic groups, defined tags, audit. |

### Platform services

| ID | Meaning |
| --- | --- |
| `ARCH-SVC-KMS` | OCI Vault / KMS — encryption key management. |
| `ARCH-SVC-LOGGING` | OCI Logging. |
| `ARCH-SVC-MONITORING` | OCI Monitoring. |
| `ARCH-SVC-BACKUP-BUCKET` | OCI Object Storage backup target — reserved for I19/M9, not yet specified. |

This list grows only when a Spec needs a concept it doesn't already cover.
Don't pre-mint IDs for initiatives that haven't reached specification depth
yet (see `docs/00-overview/roadmap.md`'s rolling-wave planning note).

## Status of the diagram artifact

`docs/arch/cloud-deployment.mmd` — **working-tree draft, not yet
canonicalized.** A rework is present in the working tree (uncommitted)
that renames and collapses many nodes while preserving every CIDR, trust
zone, and traffic-flow class this vocabulary is built from. Every Spec
citing this vocabulary is already decoupled from that node-level churn by
construction — nothing here needs to change when the diagram is
eventually committed, canonicalized, and this note removed.
