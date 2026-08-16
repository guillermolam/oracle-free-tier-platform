# Architecture view catalog

Every diagram in `docs/01-architecture/` (and the standalone
`docs/arch/cloud-deployment.mmd`) answers exactly one architectural
question. See [`README.md`](README.md) for the L0–L4 level model this
catalog uses, and [`traceability.md`](traceability.md) for how each view
maps to Specs and ARCH-* concept IDs.

## Active views

### VIEW-CONTEXT-PLATFORM

- **File:** `context/platform-context.mmd`
- **Level:** L0 — System Context
- **Purpose:** What is this platform and what external systems interact
  with it?
- **Audience:** Everyone — first thing a new reader or agent should see.
- **Scope:** Platform, internet users, administrator, GitHub, OCI tenancy,
  future on-prem/other-cloud.
- **Out of scope:** Route tables, VNICs, NSGs, individual nodes.
- **Governing Specs:** none directly — derived from `docs/00-overview/vision.md`
  and `CONTRIBUTING.md`.
- **Related views:** VIEW-CLOUD-DEPLOYMENT
- **Status:** Active

### VIEW-CLOUD-DEPLOYMENT

- **File:** `../arch/cloud-deployment.mmd` (unchanged location — see
  [README.md](README.md#on-docsarchcloud-deploymentmmd))
- **Level:** L1 — Cloud Deployment
- **Purpose:** Where are the major platform components deployed?
- **Audience:** Platform/Cloud Engineers, Security Engineers, autonomous
  agents needing the full-system picture.
- **Scope:** Tenancy, compartment, region, VCN, trust zones, Talos
  control-plane/workers, OpenZiti routers, storage, traffic-class flows.
- **Out of scope:** Nothing — this is intentionally the most detailed
  single view, which is exactly the problem this catalog exists to
  relieve going forward (see README's "one diagram" note).
- **Governing Specs:** all M1 Specs, transitively.
- **Related views:** every view in this catalog is a narrower projection
  of what this view already shows.
- **Status:** Active — canonicalized (see `traceability.md`).

### VIEW-NET-OVERVIEW

- **File:** `network/network-overview.mmd`
- **Level:** L2 — Domain Architecture (Network)
- **Purpose:** How is the VCN segmented, without Kubernetes/platform
  implementation noise?
- **Audience:** Cloud Engineers, Platform Engineers.
- **Scope:** Tenancy → compartment → region → VCN → 4 zones + CIDRs, all 4
  gateways, OCI services network, hybrid placeholder.
- **Out of scope:** Explicit route-table objects (see VIEW-NET-ROUTING),
  NSGs/Security Lists (see the per-zone views).
- **Governing Specs:** `SPEC-OCI-001`, `SPEC-NET-001`, `SPEC-NET-002`,
  ADR-0006, ADR-0008.
- **Related views:** VIEW-NET-ROUTING, VIEW-NET-TRAFFIC
- **Status:** Active

### VIEW-NET-ROUTING

- **File:** `network/routing.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** Which subnet reaches which destination through which next
  hop?
- **Audience:** Cloud Engineers, Platform Engineers, Security Engineers,
  autonomous implementation agents.
- **Scope:** All 4 route tables and all 4 gateways, un-collapsed, with the
  exact REQ-NET-012..015 route intent.
- **Out of scope:** Does NOT answer "how does Cilium route pod traffic?"
  (that's I07's future VIEW-K8S-NETWORK).
- **Governing Specs:** `SPEC-NET-002`, `SPEC-NET-003`, ADR-0008.
- **Related views:** VIEW-NET-OVERVIEW
- **Status:** Active

### VIEW-NET-TRAFFIC

- **File:** `network/traffic-flows.mmd`
- **Level:** L2 — Domain Architecture (security-relevant flows)
- **Purpose:** What are the seven traffic classes, independent of OCI
  resource inventory?
- **Audience:** Security Engineers, autonomous agents building the threat
  model (EPIC-TM-01).
- **Scope:** ARCH-FLOW-INGRESS/EGRESS/SERVICE/BACKUP/ADMIN/CONTROL/HYBRID,
  RED/GREEN/BLUE/PURPLE/ORANGE color model preserved.
- **Out of scope:** OCI resource-level detail (see VIEW-NET-OVERVIEW,
  VIEW-NET-ROUTING).
- **Governing Specs:** `SPEC-NET-005`, ADR-0008.
- **Related views:** VIEW-NET-ROUTING, all zone-detail views
- **Status:** Active

### VIEW-NET-EDGE

- **File:** `network/edge-zone.mmd`
- **Level:** L3 — Zone Detail
- **Purpose:** How is the Edge trust zone configured?
- **Audience:** Cloud/Security Engineers, autonomous agents implementing
  `SPEC-NET-004`.
- **Scope:** Public IPs, ingress + Ziti edge router placement, Edge
  Security List, `ingress`/`ziti` NSGs, Edge Route Table.
- **Out of scope:** Ingress *technology* selection — explicitly marked as
  an open decision point, not invented.
- **Governing Specs:** `SPEC-NET-001`, `SPEC-NET-002`, `SPEC-NET-004`,
  ADR-0003.
- **Related views:** VIEW-NET-MANAGEMENT (Ziti private router downstream)
- **Status:** Active

### VIEW-NET-MANAGEMENT

- **File:** `network/management-zone.mmd`
- **Level:** L3 — Zone Detail
- **Purpose:** How is the Management trust zone configured?
- **Audience:** Cloud/Security Engineers, autonomous agents.
- **Scope:** Control-plane compute placement, Kubernetes API, etcd, Ziti
  private router, Management Security List, `control` NSG, Management
  Route Table. Explicitly states: no public IP, API not internet-exposed.
- **Out of scope:** Talos machine-config detail and etcd internals — owned
  by I04/I05, marked unspecified rather than invented.
- **Governing Specs:** `SPEC-NET-001`, `SPEC-NET-003`, `SPEC-NET-004`
  (REQ-NET-019), ADR-0002, ADR-0003.
- **Related views:** VIEW-NET-EDGE, VIEW-NET-WORKLOAD
- **Status:** Active

### VIEW-NET-WORKLOAD

- **File:** `network/workload-zone.mmd`
- **Level:** L3 — Zone Detail
- **Purpose:** How is the Workload trust zone configured?
- **Audience:** Cloud/Security Engineers, autonomous agents.
- **Scope:** Worker-node placement, `worker` NSG, Workload Security List,
  Workload Route Table, NAT/Service Gateway access, control-plane
  relationship. States: no public IP.
- **Out of scope:** Worker compute/shape detail (I04) and volume-mount
  mechanics (I15) — marked unspecified.
- **Governing Specs:** `SPEC-NET-001`, `SPEC-NET-003`, `SPEC-NET-004`
  (REQ-NET-017, REQ-NET-019).
- **Related views:** VIEW-NET-MANAGEMENT, VIEW-NET-DATA
- **Status:** Active

### VIEW-NET-DATA

- **File:** `network/data-zone.mmd`
- **Level:** L3 — Zone Detail
- **Purpose:** How is the Data trust zone configured, and where does its
  network responsibility end?
- **Audience:** Cloud/Security/Storage-adjacent Engineers.
- **Scope:** Storage-zone network placement, `storage` NSG, Data Security
  List, Data Route Table, Service Gateway path toward Object Storage.
- **Out of scope:** Block-volume attachment mechanics (I15) and backup
  implementation (I19) — both explicitly marked unspecified/reserved
  rather than a fabricated topology.
- **Governing Specs:** `SPEC-NET-001`, `SPEC-NET-003`, `SPEC-NET-004`.
- **Related views:** VIEW-NET-WORKLOAD, VIEW-NET-TRAFFIC
- **Status:** Active

## Planned views

Registered so they aren't reinvented ad hoc later, and so their absence is
visible rather than silent. Elaborated only once their owning initiative
reaches specification depth — see `docs/00-overview/roadmap.md`.

| View ID | Domain | Owning initiative | Elaborated at |
| --- | --- | --- | --- |
| VIEW-K8S-CLUSTER | Kubernetes cluster topology | I05 | M2 |
| VIEW-K8S-NETWORK | Cilium/CNI, NetworkPolicy | I07 | M3 |
| VIEW-SECURITY-ZTNA | OpenZiti application-layer behavior | I08 | M3 |
| VIEW-IDENTITY | SPIFFE/SPIRE + human IdP/OIDC | I09, I10 | M4 |
| VIEW-SECRETS | OpenBao, ESO, PKI | I11 | M4 |
| VIEW-SECURITY-TRUST-BOUNDARIES | DFD-derived trust boundaries | I20 (EPIC-TM-01) | ongoing from M0, first artifact expected around M3 |
| VIEW-STORAGE | Longhorn/SeaweedFS/backup topology | I15 | M6 |
| VIEW-OBSERVABILITY | Metrics/logs/traces architecture | I16 | M7 |
| VIEW-SUPPLY-CHAIN | Image signing, SBOM | I18 | M8 |
| VIEW-HYBRID | Real DRG peering/routing once active | I21 | M11 |

## Dynamic flow views

Evaluated per §6 of the multi-view directive against every candidate
sequence (internet ingress, admin→Ziti→API, worker→NAT→internet,
worker→SGW→OCI service, backup→SGW→Object Storage, control-plane↔worker,
future hybrid→DRG→VCN). **None created in this pass.** M1 has no running
component yet — every one of those sequences would currently just restate
VIEW-NET-TRAFFIC's static paths in a different notation without adding
information a reader can't already get from it (no auth handshake,
retry, or timeout behavior exists yet to describe). Revisit once I05/I08
give these flows actual runtime behavior to document.
