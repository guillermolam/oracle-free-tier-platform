# Specs

A Spec (`SPEC-<AREA>-<NNN>.md`) is the canonical, versioned record of
**what** a capability must do and **why** — reviewed and merged like code,
not written once into a GitHub issue and left to rot behind "Closed".

GitHub is excellent at tracking who's doing what and when. It is a poor
permanent home for architectural intent: a 300-line issue is how future
maintainers end up excavating closed tickets for lost decisions. So this
repository keeps the contract here, and uses GitHub only for the
disposable, mutable layer on top of it:

```text
docs/specs/SPEC-NET-007.md          <- canonical WHAT + WHY + contract
             |
             v
     GitHub Feature                 <- product capability
             |
             +-- GitHub Story        <- executable increment
             +-- GitHub Enabler
             +-- GitHub Spike
                      |
                      v
                 Pull Request
                      |
          +-----------+------------+
          v           v            v
        Tests        ADR        Diagrams
          |           |            |
          +-----------+------------+
                      |
                      v
                 SPEC verified
```

| Artifact | Lives in | Owns |
| --- | --- | --- |
| `SPEC-*.md` | `docs/specs/` (git) | The durable contract: WHAT + WHY, numbered `REQ-*` requirements, interfaces, constraints, security/threat-model/ADR/diagram impact, acceptance criteria, verification commands. |
| GitHub Feature | GitHub Issues | Product framing — persona, milestone, priority, links to the Spec(s) it delivers. No requirements text duplicated here. |
| GitHub Story / Enabler / Spike | GitHub Issues | A bounded execution contract for one agent session: Agent Context, Read First (the exact Spec path + section), Allowed Scope, Protected Scope, Required Outcome, Required Validation, Required Evidence, Stop Conditions. Points at the Spec; does not re-derive it. |
| Pull Request | GitHub | The diff. Description references the Story issue *and* the Spec file path. |
| Tests, ADRs, Diagrams | repo (git) | Produced by the PR, committed alongside the code, permanent. |

Traceability runs through a stable path (`docs/specs/SPEC-NET-007.md`), not
a mutable issue number. When an issue is eventually closed and archived,
the knowledge it executed against is still sitting at the same path it was
on day one.

## Spec template

Every Spec MUST contain, in order: **SPEC-ID**, **Title**, **Status**
(`Draft`/`Ready`/`Blocked`/`In Progress`/`Validation`/`Done`/`Deferred`),
**Context**, **Problem Statement**, **Goals**, **Non-Goals**,
**Requirements** (numbered `REQ-<AREA>-NNN`, normative MUST/MUST NOT/
SHOULD/SHOULD NOT/MAY language only), **Constraints**, **Interfaces**,
**Dependencies** (exact Spec IDs), **Security Requirements**, **Failure
Modes**, **Observability Requirements**, **Acceptance Criteria**
(Given/When/Then), **Verification** (exact commands), **Documentation
Impact**, **Diagram Impact**, **ADR Impact**, **Threat Model Impact**,
**Operational Impact**, **Rollback / Recovery**, and a combined
**Definition of Ready / Definition of Done** section that either states
domain-specific additions or cites the global DoR/DoD below verbatim.
"None" is a valid, explicit value for any Impact field — silence is not.

**Diagram Impact** cites stable architecture concept IDs
(`ARCH-*`, defined in
[`docs/01-architecture/traceability.md`](../01-architecture/traceability.md))
plus the artifact path — for example `Architecture Impact: ARCH-FLOW-INGRESS,
ARCH-FLOW-EGRESS. Diagram: docs/arch/cloud-deployment.mmd`. It never cites a
raw Mermaid node, group, or junction name: those are implementation details
of one rendering and may be renamed or restructured without invalidating any
Spec. See `docs/01-architecture/traceability.md` for the full rationale and
the Requirement → `ARCH-*` ID → diagram artifact → Mermaid nodes chain.

## Current Specs

| Spec | Title | Status | Initiative |
| --- | --- | --- | --- |
| [SPEC-OCI-001](SPEC-OCI-001.md) | OCI tenancy, compartment, IAM, and state foundation | Ready | I02 |
| [SPEC-OCI-002](SPEC-OCI-002.md) | OCI Vault and KMS foundation | Ready | I02 |
| [SPEC-OCI-003](SPEC-OCI-003.md) | OCI Logging, Monitoring, and Audit foundation | Ready | I02 |
| [SPEC-NET-001](SPEC-NET-001.md) | OCI VCN and trust-zone subnet foundation | Ready | I03 |
| [SPEC-NET-002](SPEC-NET-002.md) | Gateways: IGW / NAT / Service Gateway / DRG | Ready | I03 |
| [SPEC-NET-003](SPEC-NET-003.md) | Trust-zone route tables | Ready | I03 |
| [SPEC-NET-004](SPEC-NET-004.md) | Security Lists and purpose-built NSGs | Ready | I03 |
| [SPEC-NET-005](SPEC-NET-005.md) | Traffic-flow invariants (verification only, no state unit) | Ready | I03 |
| [SPEC-NET-006](SPEC-NET-006.md) | VCN DNS resolver and DHCP options | Ready | I03 |

More Specs are added milestone by milestone rather than all at once — see
[`docs/00-overview/roadmap.md`](../00-overview/roadmap.md) for the full
initiative/milestone model this backlog is drawn from.

## Definition of Ready (global)

A Story/Enabler is Ready only when: purpose is clear · a Spec exists with
numbered `REQ-*` requirements · acceptance criteria are Given/When/Then and
testable · dependencies are named by Spec/Issue ID · blocking ADRs are
merged · blocking Spikes have a Decision Artifact · architecture and
threat-model impact are known (even if "None") · required interfaces are
defined · test strategy is defined · required docs are identified ·
secrets/credential strategy is defined without embedding secrets · the
issue is sized to one reviewable engineering outcome.

## Definition of Done (global)

Implementation complete · `tofu fmt -recursive` / `tofu validate` /
`tflint` / `checkov` clean where infra is touched · `pre-commit run
--all-files` clean · CI green (`validate`, `security`, `docs`, `dco`,
`plan` as applicable) · acceptance criteria verified · docs updated ·
diagrams updated when architecture changed · ADR created/updated when a
decision changed · threat model updated when trust boundaries changed ·
runbook/operational impact addressed · observability added where required
· rollback path validated · no plaintext secrets (gitleaks-enforced) · no
unresolved Critical/High finding without documented risk acceptance ·
commits GPG-signed with DCO trailer · PR reviewed and squash-merged ·
implementation traces to its Spec and Issue ID.
