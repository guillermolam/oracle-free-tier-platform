---
name: repo-audit
description: Runs docs-governance-auditor and state-safety-auditor in sequence and aggregates their findings into one report.
when_to_use: A periodic, deliberate governance sweep across docs and state/secrets safety — not for routine single-file tasks, which should delegate to the individual agents directly.
disable-model-invocation: true
user-invocable: true
---

# /repo-audit

This is real multi-agent orchestration, not an alias for a single agent —
run both audits and combine their output:

1. Invoke the `docs-governance-auditor` agent for a governance sweep across
   Mermaid diagrams, ADRs, and the threat-model corpus.
2. Invoke the `state-safety-auditor` agent for a read-only audit of the
   Terragrunt/OpenTofu backend config and the `tg` credential wrapper.
3. Combine both agents' findings into one report, clearly attributed to
   which agent produced which finding. Don't run them in a way that lets
   one agent's output influence the other's — they're independent checks
   over unrelated parts of the repo, so run them in parallel if the
   orchestration mechanism available to you supports it.

If either agent reports a security-relevant finding (a leaked secret, a
regression in the credential-reference-not-value pattern), surface it first
and prominently, ahead of routine docs-governance findings.
