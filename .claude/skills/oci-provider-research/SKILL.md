---
name: oci-provider-research
description: Bounded procedure for researching OCI Terraform/OpenTofu provider resource behavior and citing findings accurately. Use when a plan needs facts about an OCI resource's schema, defaults, quota behavior, or import semantics.
when_to_use: iac-planner needs an authoritative answer about how an oci_core_* (or other OCI provider) resource actually behaves before proposing it in a plan.
allowed-tools: WebFetch, WebSearch, Read
---

# OCI provider research

This is a research procedure, not a knowledge base — it does not cache OCI
provider facts, because those facts belong to the provider's own docs and
should always be looked up fresh.

## Where to look, in order

1. **OpenTofu/Terraform OCI provider registry docs** —
   `registry.terraform.io/providers/oracle/oci/latest/docs/resources/<resource>`
   for the resource's exact schema (required/optional args, computed
   attributes, known limitations).
2. **OCI's own API reference** (docs.oracle.com/en-us/iaas/api/) only when the
   provider docs are ambiguous about underlying service behavior (e.g.,
   whether a resource has an implicit default sub-resource created by the
   platform, not the provider).
3. **This repo's own prior art** — grep `infrastructure/modules/**/*.tf` for
   an existing use of the same resource type before assuming novel behavior;
   the repo may already have discovered and documented a quirk (see e.g. the
   DRG-inert-route-table pattern in `gateways.tf`).

## Console vs. provider-managed defaults

These are not the same thing and mixing them up produces wrong plans:

- OCI's web console sometimes auto-creates or auto-populates a sub-resource
  (a default route table, a default security list) when you create a parent
  resource through the console.
- The Terraform/OpenTofu provider does **not** replicate this — creating a
  parent resource via the provider does not implicitly create or manage that
  default sub-resource unless you also declare it explicitly. Always check
  the provider resource docs for "default resource" language before assuming
  parity with console behavior.

## Citation format

When reporting a finding back to `iac-planner`, cite the exact doc URL and
quote the specific line/argument, not just "the docs say." A plan citing
"per `oci_core_drg_route_table`'s `import_drg_route_distribution_id`
argument (optional, no propagation if unset)" is verifiable; a plan citing
"OCI docs say DRG route tables need this" is not.

## Import-block limitation to flag

OpenTofu's `import` block currently only works in the **root module** — if a
resource under consideration lives inside a nested module
(`infrastructure/modules/**`), flag this constraint explicitly in the plan
rather than silently proposing an import that won't work as declared.
