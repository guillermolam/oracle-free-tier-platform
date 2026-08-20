---
name: state-audit
description: Invokes the state-safety-auditor agent for a deliberate, explicit-only audit of the Terragrunt/OpenTofu backend config and the tg credential wrapper.
when_to_use: Before or after any change to tg, root.hcl, or credential-resolution code, or as a periodic standalone security check.
disable-model-invocation: true
user-invocable: true
agent: state-safety-auditor
---

# /state-audit

Delegate to the `state-safety-auditor` agent. This is explicit-only
(`disable-model-invocation: true`) deliberately — it's a security-sensitive
audit the user should trigger consciously, not something the model decides
to run on its own judgment. Present the agent's pass/fail findings verbatim,
with file:line citations intact.
