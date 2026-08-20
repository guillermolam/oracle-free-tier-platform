---
name: terragrunt-workflow
description: How to run Terragrunt/OpenTofu safely in this repo — unit boundaries, the tg credential wrapper, and what never to touch directly. Use when planning, scoping, or reasoning about any change under infrastructure/live/** or infrastructure/modules/**.
when_to_use: Any infrastructure change-design task, or a question about which Terragrunt unit/OpenTofu module owns a given resource.
allowed-tools: Read, Grep, Glob, Bash(tofu fmt*), Bash(tofu validate*), Bash(terragrunt plan*), Bash(terragrunt hcl fmt --check*)
---

# Terragrunt workflow

This is a navigational skill: it tells you where the facts live and the exact
commands to run. It does not restate the facts themselves — read the linked
docs for those.

## Unit boundaries (read first)

Read [docs/02-decisions/ADR-0007](../../../docs/02-decisions) before proposing
any change that might need a new Terragrunt unit. As of M1 there are exactly
two live units under `infrastructure/live/oci/eu-madrid-1/lab/`:
`00-foundation` and `10-network`. `40-storage` and `90-hybrid` are named but
deferred — do not create them speculatively. A change belongs in an existing
unit unless ADR-0007's Option-C boundary rules say otherwise.

## Never touch these directly

- `infrastructure/live/root.hcl`'s backend block (`access_key`/`secret_key`
  intentionally absent, `shared_credentials_files`/`shared_config_files`
  pointed at nonexistent paths, `use_lockfile = false`) — any proposed change
  here is `state-safety-auditor`'s job, not a plan-only change. Read
  `infrastructure/README.md`'s secrets/credentials section for why each of
  these exists before touching any of them.
- The DRG route table under `infrastructure/modules/network/gateways.tf` —
  it is deliberately inert (`import_drg_route_distribution_id` unset) per
  [ADR-0008](../../../docs/02-decisions) until initiative I21. A plan that
  populates it is out of scope for M0/M1.

## How to run things

Always go through `infrastructure/live/scripts/tg` for anything that needs
real backend credentials — never invoke `pass-cli` directly, and never assume
`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` are already set in the shell.

```sh
# format/validate — no credentials needed
tofu fmt -check -recursive infrastructure/modules/<module>
cd infrastructure/live/oci/eu-madrid-1/lab/<unit> && tofu init -backend=false && tofu validate

# plan — needs credentials, goes through tg
infrastructure/live/scripts/tg plan   # run from the unit's terragrunt.hcl directory
```

`terragrunt hcl fmt --check` is safe to run directly (no credentials).

## What a plan must cite

Every proposed resource needs a governing Spec (`docs/specs/SPEC-OCI-*` or
`SPEC-NET-*`) or ADR citation. If you can't find one, that's a signal the
change belongs in central-orchestration (per `AGENTS.md`'s routing model),
not a plan-only task.
