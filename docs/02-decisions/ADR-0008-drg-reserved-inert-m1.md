# ADR-0008: Reserve the DRG in M1; defer hybrid routing to I21

Status: Accepted

## Context

`docs/arch/cloud-deployment.mmd` depicts a Dynamic Routing Gateway (DRG)
as part of the VCN gateway set, with hybrid connectivity to future
on-prem/other-cloud environments explicitly marked as a later capability
(I21, M11 — deferred). `SPEC-NET-002` (REQ-NET-009) requires the DRG
object to be created and attached in M1 despite I21 not starting until
M11. This is a real decision with a real alternative — don't create the
DRG until I21 — so it gets its own ADR rather than being buried as a
requirement with no rationale.

## Decision

**Options considered:**

- **A.** Don't create the DRG at all until I21 begins — smallest M1
  footprint, no unused resource sitting around.
- **B.** Create the DRG and attach it in M1, with an explicitly empty DRG
  route table (no propagation, no static routes) — present but inert.
- **C.** Create the DRG in M1 **and** begin wiring real hybrid routes/
  peering now, ahead of I21's own milestone.

**Decision drivers:** this program's explicit rule that deferred work must
still exist in the roadmap and be marked as such, not silently omitted
(`docs/00-overview/roadmap.md`); avoiding a disruptive network
re-architecture when I21 eventually starts (adding a DRG later means
re-touching every route table that would reference it); OCI Free Tier cost
(a DRG attachment carries no direct cost); avoiding scope creep into I21's
actual hybrid-connectivity work, which requires its own spike
(`SPIKE-HYBRID-01`) and decisions not yet resolved.

**Decision: Option B.** The DRG is created and attached to the VCN in M1
(`SPEC-NET-002`, REQ-NET-009), with its DRG route table required to hold
zero route rules and route-table propagation disabled — corrected during
PR #18 review, since OCI requires every DRG attachment to reference a
route table (an attachment can't have "zero associations"; it can have an
empty one). `SPEC-NET-003`'s Management route table (REQ-NET-015) reserves
an unpopulated route-rule slot for the DRG, so the network topology
doesn't need to change shape when I21 begins — only new route rules and
DRG route distributions get added, not new gateways or route tables.
`SPEC-NET-005` (REQ-NET-027) verifies this inert state holds.

## Consequences

One extra always-present OCI resource (the DRG + its attachment) with
zero functional behavior until I21 — acceptable since it carries no cost
and no security exposure. Anyone inspecting the applied M1–M10
infrastructure will see a DRG that appears to do nothing; this ADR is the
explanation, cross-referenced from `SPEC-NET-002` and `SPEC-NET-005`.

## Security consequences

An attached-but-empty DRG has no traffic-forwarding capability — the
empty-route-table requirement (REQ-NET-009) is the actual control, not the
absence of the resource. It does not expand the platform's attack surface.
`SPEC-NET-005` verifies `ARCH-FLOW-HYBRID` carries zero traffic in M1 as
part of its cross-cutting checks (REQ-NET-027).

## Operational consequences

When I21 starts, work is additive (new DRG route distributions, new route
rules) rather than requiring a new DRG resource and re-planning every
dependent route table — directly reduces I21's blast radius when that
milestone eventually executes.

## Reversibility

Fully reversible — `tofu destroy` on just the DRG resource is safe at any
point before I21 populates real routes; nothing in M1–M10 depends on the
DRG being present (`SPEC-NET-002`'s Dependencies section).

## Related Specs

`SPEC-NET-002` (REQ-NET-009), `SPEC-NET-003` (REQ-NET-015), `SPEC-NET-005`
(REQ-NET-027).
