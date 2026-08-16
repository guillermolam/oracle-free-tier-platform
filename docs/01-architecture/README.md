# Architecture

The authoritative network/trust-zone diagram lives at
[`docs/arch/cloud-deployment.mmd`](../arch/cloud-deployment.mmd). It defines,
ahead of any code: one VCN (`10.10.0.0/16`) with four trust-zone subnets
(Edge `10.10.10.0/24`, Management `10.10.20.0/24`, Workload `10.10.30.0/24`,
Data `10.10.40.0/24`), the IGW/NAT/Service Gateway/DRG gateway set, per-zone
Security Lists and purpose-built NSGs, an OpenZiti public edge router plus a
private router fronting `kube-apiserver`, Talos control plane and workers,
block storage and backup, and a DRG hybrid path reserved for future
on-prem/other-cloud connectivity. `docs/specs/SPEC-NET-001.md` through
`SPEC-NET-004.md` implement this diagram directly.

## Diagrams to be added as their owning Spec ships

Each is created by the PR that implements the Spec listed, not before —
avoids documentation drifting ahead of what's actually built.

| Diagram | Owning Spec / Initiative |
|---|---|
| `network.md` (CIDR + zone-to-subnet reference table) | SPEC-NET-001 |
| Kubernetes bootstrap sequence | I05 |
| Identity architecture (SPIFFE + human IdP) | I09, I10 |
| Secrets/PKI architecture | I11 |
| Storage architecture | I15 |
| Observability architecture | I16 |
| DFD L0/L1 + trust boundaries | I20 (EPIC-TM-01) — see [docs/03-threat-model](../03-threat-model/README.md) |

## Foundation account/compartment layout

Added by SPEC-OCI-001 once implemented (`foundation.md`): compartment
hierarchy, IAM policy scope, dynamic group match rules, tofu state backend
location.
