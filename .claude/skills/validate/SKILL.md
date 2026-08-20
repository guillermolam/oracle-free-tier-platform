---
name: validate
description: Runs the narrow validation commands AGENTS.md prescribes for docs/infra changes in one shot — Mermaid validation, markdownlint, and the full pre-commit suite.
when_to_use: Before finishing any task that touched docs or infra behavior, or whenever you want one deterministic pass over the repo's own gates.
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash(npm run validate:mermaid), Bash(npx markdownlint-cli2*), Bash(pre-commit run --all-files)
---

# /validate

Run exactly the three commands `AGENTS.md`'s "Validation workflow" section
prescribes, in order, and report pass/fail for each — don't deduplicate them
against each other even though `pre-commit run --all-files` overlaps with
the first two, since that overlap is what the source-of-truth document
itself specifies:

```sh
npm run validate:mermaid
npx markdownlint-cli2 --config .markdownlint-cli2.yaml "docs/**/*.md" "*.md" ".github/**/*.md"
pre-commit run --all-files
```

If any command fails, report the failure output and stop — don't attempt to
silently fix issues found this way; that's a separate task.
