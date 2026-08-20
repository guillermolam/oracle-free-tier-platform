---
name: threat-model-corpus
description: How to run and interpret the threat-model corpus validator, and the corpus's own invariants (no duplicate IDs, refs resolve, gaps[] required for decision-pending elements). Use when touching docs/03-threat-model/model/**.
when_to_use: Any Edit or Write under docs/03-threat-model/model/, or a question about threat-model corpus state.
allowed-tools: Bash(npm run validate:threat-model), Bash(npm run test:threat-model), Read, Grep, Glob
---

# Threat-model corpus

## Current scope — Phase 3A only

The corpus is schema + one validated instance
(`docs/03-threat-model/model/instances/network.yaml`), proof-of-concept for
the tooling. DFDs, attack paths, and the risk register (Phase 3B+) do not
exist yet. Don't imply Phase 3B work exists or is in progress — that's
exactly the kind of roadmap-reality drift `AGENTS.md` warns against. For
genuine STRIDE/attack-path analysis beyond corpus validation, that's a
separate, heavier exercise — not this skill's job.

## The commands

```sh
npm run validate:threat-model   # schema validation, scripts/validate-threat-model.mjs
npm run test:threat-model       # validator's own self-test, fixture-based
```

## Corpus invariants (enforced by the validator — know them before editing)

- No duplicate element IDs across the corpus.
- Every `*_ref` field must resolve to a real element, an `ARCH-*` concept ID,
  or the literal `EXTERNAL`. The validator checks ref *existence*, not ref
  *type* — a ref that resolves to the wrong kind of element won't be caught
  automatically, so check it by eye.
- No conflicting `same_principal` identity claims.
- Every element with `state: implemented` needs at least one
  `status: implemented` evidence entry.
- Every element with `state: decision-pending` needs at least one matching
  `gaps[]` entry — don't leave a decision-pending element without a
  documented gap.

## Read first

[docs/03-threat-model/README.md](../../../docs/03-threat-model/README.md) for
the overall pipeline (architecture corpus → normalized model → DFDs →
STRIDE/LINDDUN → attack trees → risk/controls), and
[docs/03-threat-model/model/README.md](../../../docs/03-threat-model/model/README.md)
for the schema itself — this skill doesn't restate either.
