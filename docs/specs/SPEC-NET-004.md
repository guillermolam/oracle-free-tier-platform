# SPEC-NET-004 — Security Lists and Purpose-Built NSGs

**Status:** Ready
**Initiative:** I03 Network & Trust-Zone Foundation
**Epic:** EPIC-NET-04

## Context

`docs/arch/cloud-deployment.mmd` names five purpose-built NSGs (`ziti`,
`ingress`, `control`, `worker`, `storage`) layered on top of four per-zone
Security Lists. This is the Spec with the highest security and
threat-model weight in I03: it is the actual policy enforcement point for
[ADR-0003](../02-decisions/ADR-0003-openziti-ztna.md)'s "Kubernetes API has
no direct public path" guarantee.

## Problem Statement

Subnets, gateways, and route tables (`SPEC-NET-001`–`003`) define where
traffic *can* flow topologically; nothing yet defines what traffic is
*allowed*. Without this Spec, every subnet is reachable from anything else
in the VCN by default.

## Goals

- Security Lists provide a default-deny baseline per trust-zone subnet.
- Five NSGs (`ziti`, `ingress`, `control`, `worker`, `storage`) provide the
  actual fine-grained allow rules, matching the diagram exactly.
- The Kubernetes API port is reachable only from the Ziti private router
  (administrative access) and from cluster nodes themselves (kubelet,
  kube-proxy, and other node components must reach `kube-apiserver` to
  function) — from nowhere else.

## Non-Goals

- OpenZiti application configuration itself (I08).
- Kubernetes-layer `NetworkPolicy` (I07, Cilium) — this Spec is OCI-layer
  only.

## Requirements

- **REQ-NET-016** The platform MUST create one Security List per
  trust-zone subnet (Edge/Management/Workload/Data) as the coarse-grained
  default-deny baseline.
- **REQ-NET-017** The platform MUST create five NSGs: `ziti` (Ziti
  routers), `ingress` (application ingress), `control` (Kubernetes control
  plane/API), `worker` (Talos workers), `storage` (data-zone VNICs),
  matching `docs/arch/cloud-deployment.mmd` exactly.
- **REQ-NET-018** Security Lists MUST default-deny all ingress except what
  is explicitly required for the subnet to function at the OCI platform
  level (e.g., VCN-internal DNS); NSGs are the actual enforcement point,
  Security Lists are the subnet-level backstop.
- **REQ-NET-019** The `control` NSG MUST NOT permit ingress to the
  Kubernetes API port (6443) from any source except the `ziti` NSG
  (administrative access via the Ziti private router) and the `worker`
  NSG (cluster nodes — kubelet, kube-proxy, and other node components
  must reach `kube-apiserver` to join and operate). No other NSG or CIDR
  may source port 6443.
- **REQ-NET-020** No NSG may permit ingress from `0.0.0.0/0` except
  `ingress` (application traffic, scoped to its documented application
  ports) and `ziti` (public Ziti edge listener, scoped to its documented
  port) — both explicitly, not by omission.

## Constraints

Module lives under `infrastructure/modules/network`; NSG names and
membership must match `docs/arch/cloud-deployment.mmd` 1:1 so the diagram
stays the source of truth rather than drifting from the implementation.

## Interfaces

**Input:** `vcn_id`, `subnet_ids` (from `SPEC-NET-001`). **Output:**
`nsg_ids{ziti,ingress,control,worker,storage}`, `security_list_ids{edge,
management,workload,data}`. Consumed by I04 (compute VNIC attachment) and
I08 (Ziti router placement).

## Dependencies

`SPEC-NET-001`. Informs I04 (compute) and I08 (ZTNA) directly — both must
attach VNICs to the NSGs this Spec creates.

## Security Requirements

This is the Spec's own subject matter in full: REQ-NET-019 is the single
most security-critical requirement in I03 — it is the technical
enforcement of [ADR-0003](../02-decisions/ADR-0003-openziti-ztna.md)'s
"no direct public path to the Kubernetes API" decision. Permitting the
`worker` NSG on 6443 does not weaken that guarantee — cluster nodes are
never internet-reachable (REQ-NET-003), so this is cluster-internal
traffic, not a public path. REQ-NET-020
enumerates the only two legitimate `0.0.0.0/0` ingress points in the entire
platform; any third NSG requesting `0.0.0.0/0` ingress in review is a
default-reject, not a judgment call.

## Failure Modes

A future workload NSG accidentally granting `0.0.0.0/0` on 6443 → this is
exactly what REQ-NET-019/020's acceptance criteria are written to catch in
CI (`tofu test`), not to be caught by manual review alone. A Security List
loosened to "fix" a connectivity issue instead of adding the correct NSG
rule → violates REQ-NET-018's "NSGs are the enforcement point" principle;
flagged in review against this Spec.

## Observability Requirements

`tofu plan` output attached to PR. Once I16 (Observability) exists, NSG
deny events become a Hubble/flow-log signal — out of scope for this Spec,
noted for I16 to pick up.

## Acceptance Criteria

```text
Given the security module is applied in the lab environment
When `tofu apply` completes
Then five NSGs exist named ziti, ingress, control, worker, storage
And the control NSG's only ingress rules for port 6443 source from the
  ziti NSG and the worker NSG
And no other NSG or CIDR sources port 6443 against the control NSG
And no NSG other than ingress and ziti has any rule sourcing 0.0.0.0/0
And each of the four Security Lists denies all ingress not required for
  OCI platform function
```

## Verification

```bash
tofu validate
tofu test  # infrastructure/modules/network/*.tftest.hcl, asserts REQ-NET-019/020
oci network nsg list --compartment-id $C --vcn-id $VCN
oci network nsg-rules list --nsg-id $CONTROL_NSG  # confirms 6443 sources: ziti, worker only
```

## Documentation Impact

`docs/01-architecture/network.md` — NSG/Security List table (completes the
network architecture doc started by `SPEC-NET-001`).

## Diagram Impact

Architecture Impact: `ARCH-FLOW-ADMIN`, `ARCH-FLOW-CONTROL`,
`ARCH-ZONE-EDGE`, `ARCH-ZONE-MGMT`, `ARCH-ZONE-WORKLOAD`, `ARCH-ZONE-DATA`.
Diagram: `docs/arch/cloud-deployment.mmd` (working-tree draft, not yet
canonicalized — see
[`docs/01-architecture/traceability.md`](../01-architecture/traceability.md)).

## ADR Impact

[ADR-0003](../02-decisions/ADR-0003-openziti-ztna.md) (this Spec is where
that ADR's guarantee becomes an enforced control) and
[ADR-0006](../02-decisions/ADR-0006-trust-zone-network-segmentation.md).

## Threat Model Impact

This Spec is the primary control EPIC-TM-01's threat model will cite for
"Kubernetes API not internet-reachable" and "no unauthorized zone-to-zone
traffic". Its five NSGs become the DFD's trust-boundary enforcement points.

## Operational Impact

NSG rule changes post-launch are a reviewable, audited event
(`CODEOWNERS`-gated on `infrastructure/live/`) — tracked as a day-2
runbook entry once I24 exists, not enforced by this Spec.

## Rollback / Recovery

Safe to `tofu destroy` before I04/I08 attach VNICs to these NSGs. After
that, rollback is a new PR narrowing or widening a specific rule, never a
manual console edit — a manual NSG edit is exactly the drift I23's
detection exists to catch.

## Definition of Ready / Definition of Done

Per the global DoR/DoD in [`docs/specs/README.md`](README.md); no
domain-specific additions.
