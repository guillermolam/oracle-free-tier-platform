---
name: pr-ready
description: Invokes the pr-readiness-auditor agent to check whether the current change is ready to open a PR — implementation review, validation status, git/DCO/GPG hygiene.
when_to_use: Before opening a PR, or whenever a structured pass/fail checklist for the current diff is needed.
disable-model-invocation: true
user-invocable: true
agent: pr-readiness-auditor
---

# /pr-ready

Delegate to the `pr-readiness-auditor` agent with no special input — it
inspects the live git state itself (`git status`/`diff`/`log`), runs the
repo's validation commands, and checks DCO/GPG/branch-naming/CODEOWNERS
hygiene. Present its structured pass/fail checklist back to the user
verbatim; don't summarize away specific findings.
