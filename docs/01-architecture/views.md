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

### VIEW-K8S-DEPLOYMENT

- **File:** `kubernetes/kubernetes-deployment.mmd`
- **Level:** L2 — Domain Architecture (Kubernetes)
- **Purpose:** What runs where inside the Kubernetes infrastructure?
- **Audience:** Platform Engineers, autonomous agents implementing I04/I05.
- **Scope:** Placement only. Talos control plane/workers (ADR-0002),
  containerd (ADR-0002), OpenZiti private router (ADR-0003) are real;
  Cilium/SPIRE/Flux/OpenBao/ESO/Kyverno are named in `roadmap.md`'s MVP
  definition but not yet configured; cert-manager and a runtime-security
  agent are named nowhere in this repo and shown as explicitly undecided.
- **Out of scope:** Internal configuration of any subsystem — this is
  placement, not application flow.
- **Governing Specs:** none directly — ADR-0002, ADR-0003, ADR-0004,
  ADR-0005, `docs/00-overview/roadmap.md`.
- **Related views:** VIEW-K8S-RUNTIME, VIEW-NET-MANAGEMENT, VIEW-NET-WORKLOAD
- **Status:** Active

### VIEW-K8S-RUNTIME

- **File:** `kubernetes/container-runtime.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** What is the runtime hierarchy from kubelet to the OCI runtime?
- **Audience:** Platform Engineers.
- **Scope:** kubelet → containerd (ADR-0002) → runc, with youki shown as
  the still-open `SPIKE-RT-01` alternative — never as an equivalent peer.
- **Out of scope:** Kata/gVisor — zero evidence either is being considered.
- **Governing Specs:** none directly — ADR-0002, `SPIKE-RT-01`.
- **Related views:** VIEW-K8S-DEPLOYMENT
- **Status:** Active

### VIEW-K8S-NETWORK

- **File:** `kubernetes/kubernetes-network.mmd`
- **Level:** L2 — Domain Architecture (Kubernetes)
- **Purpose:** How does traffic move through OCI, nodes, Cilium, services,
  and workloads?
- **Audience:** Platform/Security Engineers, autonomous agents implementing I07.
- **Scope:** OCI/node/pod/service network kept as distinct layers; Cilium
  named (roadmap.md); Pod/Service CIDR marked DECISION PENDING (no Spec
  sets them); Hubble and Gateway API marked as zero-evidence candidates.
  OpenZiti's identity overlay explicitly not conflated with Cilium identity.
- **Out of scope:** OpenZiti policy internals (see VIEW-ID-ZITI).
- **Governing Specs:** none directly — `docs/00-overview/roadmap.md`.
- **Related views:** VIEW-ID-ZITI, VIEW-NET-OVERVIEW
- **Status:** Active

### VIEW-K8S-SECURITY-BOUNDARIES

- **File:** `kubernetes/kubernetes-security-boundaries.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** Where are the major Kubernetes security boundaries?
- **Audience:** Security Engineers, future threat-model phase (EPIC-TM-01).
- **Scope:** A boundary inventory (OCI VCN through runtime security),
  each boundary labeled by its actual evidence status — not a
  configuration.
- **Out of scope:** Configuring any boundary — that's each owning Spec's job.
- **Governing Specs:** SPEC-NET-* (transitively), ADR-0002/0003/0004.
- **Related views:** VIEW-K8S-DEPLOYMENT, VIEW-K8S-NETWORK, VIEW-ID-K8S-RBAC
- **Status:** Active

### VIEW-ID-WORKLOAD

- **File:** `identity/workload-identity.mmd`
- **Level:** L2 — Domain Architecture (Identity)
- **Purpose:** How does a Kubernetes workload obtain and use workload identity?
- **Audience:** Security Engineers, autonomous agents implementing I09.
- **Scope:** SPIFFE Trust Domain → SPIRE Server/Agent → attestation → SPIFFE
  ID/SVID, named in `roadmap.md`'s MVP definition. ServiceAccount and Pod
  shown contributing to attestation, never as the identity itself.
  Cross-cluster federation marked DECISION PENDING (`SPIKE-SPIFFE-01`).
- **Out of scope:** Kubernetes RBAC (see VIEW-ID-K8S-RBAC) — a
  ServiceAccount is a separate principal from a SPIFFE ID.
- **Governing Specs:** none directly — `docs/00-overview/roadmap.md`,
  `SPIKE-SPIFFE-01`.
- **Related views:** VIEW-ID-K8S-RBAC
- **Status:** Active

### VIEW-ID-K8S-RBAC

- **File:** `identity/kubernetes-identity-rbac.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** How are Kubernetes principals authorized?
- **Audience:** Security Engineers, future IAM/RBAC-optimization phase.
- **Scope:** The standard Kubernetes RBAC mechanism (OIDC subject/group and
  ServiceAccount → RoleBinding → Role, plus cluster-scoped
  ClusterRole/ClusterRoleBinding shown as visually distinct/privileged).
  No concrete Role content exists — I05/I09/I10 unspec'd.
- **Out of scope:** Which namespaces/roles actually exist (see
  VIEW-GOV-K8S-TENANCY).
- **Governing Specs:** none directly — standard Kubernetes RBAC applied to
  this platform's named identity sources.
- **Related views:** VIEW-ID-HUMAN, VIEW-ID-WORKLOAD, VIEW-GOV-K8S-TENANCY
- **Status:** Active

### VIEW-GOV-K8S-TENANCY

- **File:** `governance/kubernetes-tenancy.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** Where are namespace, policy, identity, and ownership boundaries?
- **Audience:** Platform Engineers, future IAM/RBAC-optimization phase.
- **Scope:** A candidate namespace taxonomy (none Spec'd — I05 has zero
  depth) plus the generic per-namespace structure (ServiceAccount, RBAC,
  NetworkPolicy, admission, quota, secrets, ownership) every real
  namespace will carry once specified.
- **Out of scope:** Asserting any namespace as decided.
- **Governing Specs:** none — explicitly provisional pending I05.
- **Related views:** VIEW-ID-K8S-RBAC, VIEW-K8S-SECURITY-BOUNDARIES
- **Status:** Active

### VIEW-CICD-PLATFORM-GITOPS

- **File:** `cicd/platform-gitops-pipeline.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** How does a platform-manifest change reach the cluster?
- **Audience:** Platform Engineers, autonomous agents implementing I12.
- **Scope:** The pipeline shape ADR-0005 already mandates (Flux
  reconciles, GitHub Actions never deploys); every stage's specifics
  (validation job, policy check, `platform/` layout) marked PLANNED.
- **Out of scope:** Kyverno policy content (see VIEW-CICD-POLICY).
- **Governing Specs:** none directly — ADR-0005.
- **Related views:** VIEW-CICD-POLICY, VIEW-GOV-PLATFORM
- **Status:** Active

### VIEW-CICD-POLICY

- **File:** `cicd/policy-pipeline.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** How does a policy change reach enforcement?
- **Audience:** Security Engineers, autonomous agents implementing I14.
- **Scope:** Kyverno (ADR-0004) and Cilium policy (roadmap.md) named as
  the engines; policy content, tests, and CI wiring all marked PLANNED.
  Conftest/OPA not shown — zero evidence either is used in this repo.
- **Out of scope:** Namespace-level policy assignment (see
  VIEW-GOV-K8S-TENANCY).
- **Governing Specs:** none directly — ADR-0004.
- **Related views:** VIEW-CICD-PLATFORM-GITOPS
- **Status:** Active

### VIEW-CICD-NODE-CONFIG

- **File:** `cicd/node-configuration-pipeline.mmd`
- **Level:** L3 — Component Detail
- **Purpose:** How is a Talos node configuration change applied safely?
- **Audience:** Platform Engineers, autonomous agents implementing I04.
- **Scope:** The pipeline shape ADR-0002's explicit "no SSH, only
  talosctl" constraint mandates; every stage's specifics marked PLANNED.
- **Out of scope:** Compute provisioning itself (see `SPEC-OCI-*`).
- **Governing Specs:** none directly — ADR-0002, `CONTRIBUTING.md`.
- **Related views:** VIEW-K8S-DEPLOYMENT
- **Status:** Active

## Planned views

Registered so they aren't reinvented ad hoc later, and so their absence is
visible rather than silent. Elaborated only once their owning initiative
reaches specification depth — see `docs/00-overview/roadmap.md`.

| View ID | Domain | Owning initiative | Elaborated at |
| --- | --- | --- | --- |
| VIEW-SECURITY-ZTNA-POLICY | OpenZiti dial/bind/service policy objects (network-identity intersection is already Active — see VIEW-ID-ZITI) | I08 | M3 |
| VIEW-SERVICE-MESH | Service mesh / mTLS layer ownership | **undecided — no initiative names this decision yet** | unscheduled |
| VIEW-SECRETS | OpenBao, ESO, PKI | I11 | M4 |
| VIEW-SECURITY-TRUST-BOUNDARIES | DFD-derived trust boundaries | I20 (EPIC-TM-01) | ongoing from M0, first artifact expected around M3 |
| VIEW-STORAGE | Longhorn/SeaweedFS/backup topology | I15 | M6 |
| VIEW-OBSERVABILITY | Metrics/logs/traces architecture | I16 | M7 |
| VIEW-CICD-APPLICATION | Application container pipeline | **no owning initiative — this program's I01-I25 model has no application-workload initiative; may never apply unless one is added** | unscheduled |
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
