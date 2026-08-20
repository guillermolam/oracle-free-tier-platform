# Roadmap

25 initiatives, each carrying 2–4 epics, cover all platform domains. Full
initiative/epic detail and the coverage matrix tracing every domain to its
owning initiative live in the delivery-program planning artifact published
alongside this scaffold; this file tracks the stable, repo-native summary.

## Critical path (gates the MVP demo)

```text
I01 Foundation & Governance
  -> I02 OCI Cloud Foundation
  -> I03 Network & Trust-Zone Foundation
  -> I04 Compute & Talos Foundation
  -> I05 Kubernetes Bootstrap
  -> I07 Kubernetes Networking (Cilium)
  -> I12 GitOps Platform (Flux)
  -> I15 Storage Platform
  -> I19 Backup & Disaster Recovery
  -> I24 Operations & Day-2 Readiness
```

I08 (Zero Trust Network Access) parallels I03→I05 and gates day-2 admin
access rather than the `tofu apply` critical path itself. I09 (workload
identity), I11 (secrets/PKI), I14 (policy), I16 (observability), I17
(runtime security), and I18 (supply chain) parallelize once I07 lands. I20
(threat modeling), I23 (CI), and I25 (docs) run continuously from I01
onward and are never "done". I21 (hybrid) and I22 (multi-cluster/multi-cloud)
are explicitly deferred past the MVP boundary — tracked, not omitted.

## Milestones

| Milestone | Proves | Initiatives | MVP? |
| --- | --- | --- | --- |
| M0 | Repository & specification foundation | I01, I20 (kickoff), I25 (kickoff) | yes |
| M1 | OCI network foundation | I02, I03 | yes |
| M2 | Kubernetes bootstrap | I04, I05, I06 | yes |
| M3 | Secure Kubernetes networking | I07, I08 | yes |
| M4 | Identity & secrets foundation | I09, I10, I11 | yes |
| M5 | GitOps platform | I12, I14, I13 (partial) | yes |
| M6 | Persistent storage | I15 | yes |
| M7 | Observability & runtime security | I16, I17 | yes |
| M8 | Supply chain & policy enforcement | I18 (+ I14 hardening) | yes |
| M9 | Backup & disaster recovery | I19 | yes |
| M10 | Operational readiness | I24 | yes — MVP boundary |
| M11 | Hybrid node/cluster PoC | I21 | **deferred** |
| M12 | Multi-cloud expansion | I22 | **deferred** |

## MVP definition

Internet → OCI Edge (Ziti + ingress, neither exposing the Kubernetes API) →
private Talos/Kubernetes cluster with Cilium NetworkPolicy, SPIFFE workload
identity, OpenBao + External Secrets Operator, Flux-reconciled desired
state, Longhorn/SeaweedFS storage, Prometheus/Loki/Tempo observability,
Kyverno policy, and a demonstrated backup→restore drill. Workers and
control plane hold no public IP; all egress is NAT; OCI service access uses
the Service Gateway; administrative access is ZTNA-only. Milestones M0–M10.

## Decisions already made (not spikes)

`CONTRIBUTING.md`'s ownership model and `docs/arch/cloud-deployment.mmd`
already settle: IaC = OpenTofu + Terragrunt, node OS = Talos, ZTNA =
OpenZiti, policy engine = Kyverno, GitOps controller = Flux. Recorded as
[ADR-0001](../02-decisions/ADR-0001-opentofu-terragrunt.md) through
[ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md).

## Open spikes

| Spike | Question | Blocks |
| --- | --- | --- |
| SPIKE-NET-01 | Can NAT GW (limit 0, confirmed via `oci limits`) and SGW (per-VCN limit 0) be raised on this Always Free tenancy? Console-only limit-increase request (no CLI/API path) — submitted manually; outcome decides managed gateways vs software-NAT as M1's egress mechanism | I03 |
| SPIKE-STOR-01 | Longhorn vs Rook/Ceph vs OCI Block Volume CSI under the 200 GB / 2-worker envelope | I15 |
| SPIKE-RT-01 | youki compatibility with Talos/containerd on ARM64 | I06 |
| SPIKE-COMP-01 | Ampere A1 shape split within the 4 OCPU / 24 GB total | I04 |
| SPIKE-IDP-01 | Self-hosted vs external IdP, ARM64/free-tier-sized | I10 |
| SPIKE-SPIFFE-01 | SPIFFE federation model for eventual multi-cluster | I22 |
| SPIKE-HYBRID-01 | Cross-cloud Cilium ClusterMesh feasibility over DRG | I21, I22 (deferred) |

See [docs/specs/README.md](../specs/README.md) for how each initiative
decomposes into Specs, and the Spec files under `docs/specs/` for the
requirements currently Ready to implement.
