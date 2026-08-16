# Identity reconciliation

This is the durable record behind [`VIEW-ID-*`](views.md), [`VIEW-GOV-*`](views.md),
and every `VIEW-CICD-*` identity claim: it exists so that no two views can
silently imply two different principals are interchangeable. See
[`traceability.md`](traceability.md) for the ARCH-* IDs each row below
maps to.

## Delivery identity matrix

| Workload | Human | Workflow Identity | Cloud Principal | K8s Principal | Secret Identity |
| --- | --- | --- | --- | --- | --- |
| IaC | OCI IAM User (bootstrap) | GitHub Actions workflow | Static OCI keys (REQ-OCI-006); OIDC federation PLANNED, EPIC-OCI-04 | N/A | N/A |
| Platform GitOps | GitHub contributor | GitHub Actions (validates only) | N/A | Flux ServiceAccount — PLANNED, I12 | N/A |
| Policy | GitHub contributor | GitHub Actions | N/A | Kyverno ServiceAccount — PLANNED, I14 | N/A |
| Node configuration | GitHub contributor / Platform Administrator | GitHub Actions (review only) | Instance Principal, once provisioned — PLANNED, I04 | N/A | SOPS-encrypted secrets (`CONTRIBUTING.md`); Talos-specific handling not yet Spec'd |
| Application | — | — | — | — | **ARCHITECTURE GAP — no owning initiative in the I01-I25 model; see `views.md`'s VIEW-CICD-APPLICATION entry** |

## Governance matrix

| Control Plane | Principal | Authorization Mechanism | Scope | Evidence |
| --- | --- | --- | --- | --- |
| GitHub | Contributors | Branch protection, CODEOWNERS, signed+DCO | `main`, sensitive paths | Live — branch protection API |
| OCI IAM | Human user + Dynamic Groups | Compartment-scoped policy | Platform compartment | REQ-OCI-002 |
| OCI KMS | Dynamic Group | Key-usage policy | Vault/master key | REQ-OCI-010 |
| OCI Logging | Dynamic Group | Log-write policy | Log group | REQ-OCI-015 |
| OpenZiti | Ziti identity | Dial/bind policy | `kube-apiserver` network path | ADR-0003 (path is real); policy objects PLANNED, I08 |
| Kyverno | K8s admission requests | ClusterPolicy | Cluster-wide | ADR-0004 (engine is real); rules PLANNED, I14 |
| Cilium | Pod/Service identity | CiliumNetworkPolicy | Pod/Service network | `roadmap.md` (named); rules PLANNED, I07 |
| SPIRE | Workload | SPIFFE ID issuance | Trust domain | `roadmap.md` (named); PLANNED, I09 |
| OpenBao | Workload / Human | Policy engine | Secrets | `roadmap.md` (named); PLANNED, I11 |
| Flux | N/A (controller) | Source/Kustomization RBAC | Cluster-wide | ADR-0005 (owner is real); PLANNED, I12 |

## Cross-domain identity reconciliation

None of the identities below are interchangeable. Where a mapping exists,
it's named; where it doesn't yet, that's recorded as an architecture gap
rather than assumed.

| Boundary | Same principal? | Mapping mechanism | Evidence | Gap |
| --- | --- | --- | --- | --- |
| GitHub ↔ OCI IAM | No | None automated — a human currently holds both credential sets separately | REQ-OCI-006 (static keys) | **GAP** — GitHub OIDC → OCI federation is EPIC-OCI-04, not yet built |
| GitHub ↔ Human IdP | No | None | — | **GAP** — `SPIKE-IDP-01` is still open |
| Human IdP ↔ OpenZiti | No | None documented | ADR-0003 (Ziti's own enrollment, independent of any OIDC IdP) | **GAP** — no Spec binds an OIDC login to Ziti identity issuance |
| OpenZiti ↔ Kubernetes API | No | Ziti provides network-layer reachability only; K8s authenticates separately once the packet arrives | ADR-0003, REQ-NET-019 | None at the network layer — this is by design, not a gap |
| Kubernetes API ↔ Kubernetes RBAC | No | Standard K8s separation: API server authenticates, RBAC authorizes | Standard Kubernetes design, real once I05/I10 land | None — expected separation |
| Kubernetes RBAC ↔ ServiceAccount | No, but natively integrated | ServiceAccount is one of RBAC's subject types, alongside User/Group | Standard Kubernetes design | None — expected integration |
| ServiceAccount ↔ SPIFFE/SVID | **Explicitly no** | ServiceAccount contributes to SPIRE's workload attestation; SPIRE issues a distinct SPIFFE ID | `roadmap.md` (SPIFFE named), directive's own explicit invariant | **GAP** — exact attestation mechanism (e.g. `k8s_psat` vs `k8s_sat` node attestor) not yet decided, I09 |
| SPIFFE/SVID ↔ OpenBao | No | SVID as an OpenBao auth method — planned integration point | `roadmap.md` (both named) | **GAP** — not yet Spec'd, I11 |
| OpenBao ↔ Flux | No relationship expected | External Secrets Operator, not Flux, is the named consumer of OpenBao-issued secrets | `roadmap.md` names ESO, not a direct Flux-OpenBao path | None — clarifying a relationship that shouldn't exist, not a gap |

## Summary of architecture gaps from this reconciliation

1. GitHub → OCI federation (EPIC-OCI-04) — static keys only today.
2. Human IdP selection (`SPIKE-IDP-01`) — blocks every downstream human-auth mapping.
3. OIDC login → OpenZiti identity binding — no Spec addresses this at all.
4. SPIRE node/workload attestation mechanism — named as a component, not yet configured.
5. SPIFFE ↔ OpenBao auth integration — named as a component, not yet configured.
6. Application workload pipeline has no owning initiative — a product-scope
   question, not an architecture gap this session can close.
