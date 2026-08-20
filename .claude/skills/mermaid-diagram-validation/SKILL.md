---
name: mermaid-diagram-validation
description: Runs and interprets npm run validate:mermaid, and checks ARCH-* traceability for edited diagrams. Use whenever a .mmd file under docs/01-architecture/ (or docs/arch/) is touched.
when_to_use: Any Edit or Write to a *.mmd file, or a review pass over docs/01-architecture/**.
allowed-tools: Bash(npm run validate:mermaid), Read, Grep, Glob
---

# Mermaid diagram validation

## The command

```sh
npm run validate:mermaid
```

This renders every `.mmd` file under `docs/` via `mmdc`
(`scripts/validate-mermaid.sh`), using `docs/mermaid-puppeteer-config.json`
for headless-Chromium flags. A render failure means the diagram has invalid
Mermaid syntax — fix the syntax, don't work around the validator.

## Traceability (not enforced by the validator — check by hand)

Diagrams are projections, not independent truth (per `AGENTS.md`'s core
operating rules). Every node that represents an architectural concept should
trace back to an `ARCH-*` concept ID documented in
[docs/01-architecture/traceability.md](../../../docs/01-architecture/traceability.md).
Read [docs/01-architecture/views.md](../../../docs/01-architecture/views.md)
for the L0-L4 view catalog before adding a new diagram, to confirm it belongs
in an existing view rather than introducing a parallel one.

## What NOT to do

Don't rename or restructure diagram nodes to "clean them up" without checking
whether other diagrams or `traceability.md` reference the same node by its
current label — an unrelated-looking Mermaid diff can silently break
traceability elsewhere.
