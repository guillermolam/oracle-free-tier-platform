# ADR-0006: Four-zone trust-boundary network segmentation

Status: Accepted

## Context

`docs/arch/cloud-deployment.mmd` already draws one VCN (`10.10.0.0/16`)
split into four subnets — Edge, Management, Workload, Data — each with its
own Security List and a set of purpose-built NSGs (ziti, ingress, control,
worker, storage). This ADR records that segmentation as a decision so
`docs/specs/SPEC-NET-001.md` through `SPEC-NET-004.md` implement an agreed
architecture rather than inventing one implicitly through code.

## Decision

The VCN is segmented into exactly four trust zones, each a dedicated
subnet:

| Zone | CIDR | Holds | Public IP allowed |
|---|---|---|---|
| Edge | `10.10.10.0/24` | Ingress endpoint, OpenZiti public edge router | Yes — only these two |
| Management | `10.10.20.0/24` | Talos control plane, `kube-apiserver`, etcd, OpenZiti private router | No |
| Workload | `10.10.30.0/24` | Talos workers | No |
| Data | `10.10.40.0/24` | Block storage VNICs, backup endpoint | No |

No resource outside the Edge zone may hold a public IP. Zone-to-zone and
zone-to-internet traffic is governed by per-zone route tables
(`SPEC-NET-003`) and enforced at the NSG level (`SPEC-NET-004`), with
Security Lists as the coarser subnet-level backstop.

## Consequences

- Every future OCI compute/storage resource must declare which of the four
  zones it belongs to — there is no "ungrouped" placement.
- This is the trust-boundary model EPIC-TM-01 (I20) uses as the basis for
  the first DFD and threat model, once written.
- Extending to a fifth zone (e.g., a dedicated observability zone) requires
  a superseding ADR, not an ad hoc subnet addition.
