---
name: plan-change
description: Wraps iac-planner to scope and plan an infrastructure change, requiring a governing spec/ADR citation before proceeding.
when_to_use: Any request to design or plan an infrastructure change under infrastructure/**.
argument-hint: "<spec or change description>"
agent: iac-planner
---

# /plan-change

Before delegating, confirm the invocation includes either a spec ID
(`SPEC-OCI-*`/`SPEC-NET-*`), an ADR reference, or a specific enough change
description that `iac-planner` can find the governing spec/ADR itself. If
none of these is present, ask for one rather than delegating a vague
request — `iac-planner`'s own MUST clauses require citing a governing
Spec/ADR for every proposed resource, so a vague request just produces a
STOP CONDITIONS bounce back to the main thread.

Once delegated, present `iac-planner`'s plan output verbatim, including any
explicit call-outs that need `state-safety-auditor` sign-off before a human
applies it.
