---
name: adr-authoring
description: How to write or edit an ADR under docs/02-decisions/ — when to use the light vs full shape, required sections, and updating the ADR index. Use when creating or editing a decision record.
when_to_use: A task creates a new docs/02-decisions/ADR-*.md file, edits an existing one, or needs to determine whether a change is ADR-worthy at all.
allowed-tools: Read, Grep, Glob
---

# ADR authoring

## Is this even ADR-worthy?

Per `AGENTS.md`'s central-orchestration tier: changes to network design,
identity, secrets, trust zones, platform ownership, or anything with broad
blast radius should get an ADR. A narrow implementation choice inside an
already-decided boundary usually doesn't need one — check
[docs/02-decisions/README.md](../../../docs/02-decisions/README.md)'s own
guidance before drafting.

## Shape: light vs. full

`docs/02-decisions/README.md` documents two ADR shapes. Read it before
drafting — the shape choice depends on decision weight (a reversible,
narrow decision can use the light shape; a decision that constrains future
architecture, like ADR-0006's trust-zone segmentation or ADR-0007's state
boundaries, needs the full shape). Match the existing ADRs' shape for
similar-weight decisions rather than inventing a new structure.

## Required housekeeping

After adding or editing an ADR:

1. Update the index table in `docs/02-decisions/README.md` — a new ADR that
   isn't indexed is effectively invisible to the source-of-truth chain.
2. Check whether the decision affects any `docs/01-architecture/**/*.mmd`
   diagram's traceability (see the `mermaid-diagram-validation` skill) or
   the roadmap (`docs/00-overview/roadmap.md`) — an ADR that changes scope
   without a corresponding roadmap update creates exactly the kind of
   roadmap-reality drift `AGENTS.md` warns against.

## What NOT to do

Don't retroactively edit an already-Accepted ADR's decision content to match
new reality — that's what a new, superseding ADR is for. A correction to a
factual claim inside an ADR (not the decision itself) is fine; changing the
decision after the fact is not.
