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

### VIEW-ID-OCI

- **File:** `identity/oci-identity-governance.mmd`
- **Level:** L2 — Domain Architecture (Identity)
- **Purpose:** What identity hierarchy and authorization model does OCI
  itself use?
- **Audience:** Cloud/Security Engineers, autonomous agents implementing
  `SPEC-OCI-*`.
- **Scope:** Human identity (bootstrap IAM user), machine/instance
  identity, dynamic groups, policy, compartment/resource targets — each
  shown as a distinct concept, never collapsed into one "IAM" box.
- **Out of scope:** Resource principals (not used by any current Spec,
  shown as absent rather than omitted silently); Kubernetes/workload
  identity (see VIEW-ID-WORKLOAD, planned).
- **Governing Specs:** `SPEC-OCI-001`, `SPEC-OCI-002`, `SPEC-OCI-003`.
- **Related views:** VIEW-GOV-OCI-ACCESS
- **Status:** Active

### VIEW-GOV-OCI-ACCESS

- **File:** `governance/oci-access-control.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** Who or what may access which OCI resources, through which
  principal, policy, compartment, and trust boundary?
- **Audience:** Security Engineers, autonomous agents, future IAM
  optimization phase.
- **Scope:** Principal → Group → Policy → Resource chain across every
  permission domain (KMS, logging, object storage, network, compute,
  monitoring, hybrid), each labeled PRESENT, PLANNED, or DECISION PENDING.
- **Out of scope:** Kubernetes RBAC (see VIEW-ID-K8S-RBAC, planned).
- **Governing Specs:** `SPEC-OCI-001` (REQ-OCI-002), `SPEC-OCI-002`
  (REQ-OCI-010), `SPEC-OCI-003` (REQ-OCI-015).
- **Related views:** VIEW-ID-OCI
- **Status:** Active

### VIEW-ID-HUMAN

- **File:** `identity/human-identity.mmd`
- **Level:** L2 — Domain Architecture (Identity)
- **Purpose:** How do human actors authenticate, and to what?
- **Audience:** Security Engineers, Platform Administrator, future IAM/PAM
  phase.
- **Scope:** GitHub identity (real), OpenZiti administrative identity
  (real, ADR-0003), OIDC as a mechanism (real) — the IdP itself is
  explicitly DECISION PENDING (`SPIKE-IDP-01`), not assumed.
  Authentication shown separately from authorization.
- **Out of scope:** Which OIDC product is selected — that's `SPIKE-IDP-01`'s
  job, not this view's.
- **Governing Specs:** none directly — ADR-0003, `CONTRIBUTING.md`,
  `docs/00-overview/roadmap.md` (`SPIKE-IDP-01`).
- **Related views:** VIEW-ID-ZITI
- **Status:** Active

### VIEW-ID-ZITI

- **File:** `identity/openziti-identity-network.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** How do identity and private network access intersect in
  OpenZiti?
- **Audience:** Security Engineers, autonomous agents implementing I08.
- **Scope:** WHO ARE YOU (identity) vs. WHAT MAY YOU DIAL (authorization)
  vs. WHERE DOES TRAFFIC FLOW (network path) shown as three explicitly
  separated concerns. The network path (Edge → fabric → Management → API)
  is real (ADR-0003, `SPEC-NET-004`); dial/bind policy objects are I08
  territory, marked PLANNED.
- **Out of scope:** Kubernetes RBAC — OpenZiti is not a substitute for it.
- **Governing Specs:** `SPEC-NET-002`, `SPEC-NET-004` (REQ-NET-019),
  ADR-0003.
- **Related views:** VIEW-ID-HUMAN, VIEW-NET-MANAGEMENT
- **Status:** Active

### VIEW-GOV-PLATFORM

- **File:** `governance/platform-governance.mmd`
- **Level:** L2 — Domain Architecture (Governance)
- **Purpose:** What enforces the chain from a written decision to running
  behavior, and where does that chain currently stop?
- **Audience:** Everyone — this is the single clearest "what's real vs.
  aspirational" view in the repo.
- **Scope:** Specification → PR → CI → IaC → admission → runtime → audit,
  with each stage marked PRESENT or PLANNED against what's actually
  installed today.
- **Out of scope:** Per-domain policy content (Kyverno rule bodies, once
  they exist, live in `policy/` — this view shows the chain, not the
  rules).
- **Governing Specs:** `docs/specs/README.md`'s own contract, ADR-0004,
  `SPEC-OCI-003` (REQ-OCI-014).
- **Related views:** VIEW-CICD-SUPPLYCHAIN
- **Status:** Active

### VIEW-CICD-SUPPLYCHAIN

- **File:** `cicd/software-supply-chain.mmd`
- **Level:** L2 — Domain Architecture (CI/CD)
- **Purpose:** What happens to every change between commit and running
  behavior, common across all workload classes?
- **Audience:** DevSecOps Engineers, autonomous agents, future supply-chain
  hardening phase (I18).
- **Scope:** The real, live chain through merge (lint/SAST/secret-scan/
  IaC-scan/workflow-lint/diagram-validation, all in `.github/workflows/`)
  — everything after merge (dependency scan onward) is PLANNED, since this
  repo has zero container workloads today.
- **Out of scope:** Per-workload-class detail — see VIEW-CICD-IAC and the
  planned per-class views.
- **Governing Specs:** none directly — `.github/workflows/{validate,
  security,docs,dco}.yml`, ADR-0005.
- **Related views:** VIEW-CICD-IAC, VIEW-GOV-PLATFORM
- **Status:** Active

### VIEW-CICD-IAC

- **File:** `cicd/iac-pipeline.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** What happens to an OpenTofu/Terragrunt change from commit
  to applied infrastructure?
- **Audience:** Cloud Engineers, autonomous agents implementing any
  `SPEC-OCI-*`/`SPEC-NET-*` Enabler.
- **Scope:** fmt/validate/test/tflint/security-scan/checkov/plan/auth/
  state-backend/review/apply — the only workload-class pipeline with real,
  running content today. Explicitly states GitHub Actions never applies.
- **Out of scope:** Drift detection (PLANNED, I23).
- **Governing Specs:** `SPEC-OCI-001` (REQ-OCI-005..007), ADR-0001,
  ADR-0007.
- **Related views:** VIEW-CICD-SUPPLYCHAIN
- **Status:** Active

## Planned views

Registered so they aren't reinvented ad hoc later, and so their absence is
visible rather than silent. Elaborated only once their owning initiative
reaches specification depth — see `docs/00-overview/roadmap.md`.

| View ID | Domain | Owning initiative | Elaborated at |
| --- | --- | --- | --- |
| VIEW-ID-WORKLOAD | SPIFFE/SPIRE workload identity issuance/consumption | I09 | M4 |
| VIEW-ID-K8S-RBAC | OIDC subject/ServiceAccount → RoleBinding → Role/ClusterRole | I05, I09, I10 | M2/M4 |
| VIEW-GOV-K8S-TENANCY | Namespace boundaries, quotas, admission scope | I05 | M2 |
| VIEW-K8S-DEPLOYMENT | What Kubernetes/platform component runs where | I04, I05, I06 | M2 |
| VIEW-K8S-NETWORK | Cilium/CNI, Pod/Service CIDR, NetworkPolicy | I07 | M3 |
| VIEW-K8S-SECURITY-BOUNDARIES | Cross-cutting K8s trust boundaries (depends on the four rows above existing first) | I05, I07, I09 | M3/M4 |
| VIEW-SECURITY-ZTNA-POLICY | OpenZiti dial/bind/service policy objects (network-identity intersection is already Active — see VIEW-ID-ZITI) | I08 | M3 |
| VIEW-SERVICE-MESH | Service mesh / mTLS layer ownership | **undecided — no initiative names this decision yet** | unscheduled |
| VIEW-SECRETS | OpenBao, ESO, PKI | I11 | M4 |
| VIEW-SECURITY-TRUST-BOUNDARIES | DFD-derived trust boundaries | I20 (EPIC-TM-01) | ongoing from M0, first artifact expected around M3 |
| VIEW-STORAGE | Longhorn/SeaweedFS/backup topology | I15 | M6 |
| VIEW-OBSERVABILITY | Metrics/logs/traces architecture | I16 | M7 |
| VIEW-CICD-PLATFORM-GITOPS | Flux reconciliation pipeline | I12 | M5 |
| VIEW-CICD-APPLICATION | Application container pipeline | **no owning initiative — this program's I01-I25 model has no application-workload initiative; may never apply unless one is added** | unscheduled |
| VIEW-CICD-POLICY | Kyverno/Cilium/Conftest policy pipeline | I14 | M8 |
| VIEW-CICD-NODE-CONFIG | Talos node configuration pipeline | I04 | M2 |
| VIEW-CICD-SECURITY-CONTENT | Tetragon/Falco security-content pipeline | I17 | M7 |
| VIEW-SUPPLY-CHAIN-CONTENT | SBOM/signing/provenance detail populating VIEW-CICD-SUPPLYCHAIN's already-scaffolded shape | I18 | M8 |
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
