---
name: secrets-boundary-check
description: Checklist for verifying no secret value has landed in a diff, log, or persisted file, and that credential resolution still follows the reference-not-value pattern. Use before finishing any task that touched credential/backend config or produced a diff.
when_to_use: Before iac-planner, state-safety-auditor, or pr-readiness-auditor report a task complete, if the task touched infrastructure/live/scripts/tg, infrastructure/live/root.hcl, or any file that could plausibly contain credential material.
allowed-tools: Read, Grep, Bash(git diff*), Bash(git status*)
---

# Secrets boundary check

## Never-commit list (from AGENTS.md)

Credentials, `.oci` material, Talos secrets, kubeconfigs, `.env` files,
unencrypted SOPS files. Run `git diff --cached` (or `git diff` for unstaged
work) and grep the output for these shapes before calling anything done:

```sh
git diff --cached -- . ':!*.lock' | grep -inE 'BEGIN (RSA|OPENSSH|PGP) PRIVATE KEY|aws_secret|AKIA[0-9A-Z]{16}|-----BEGIN'
```

This is a spot check, not a replacement for gitleaks (already wired into
`.pre-commit-config.yaml` and `.github/workflows/security.yml`) — if
`gitleaks` is on `PATH`, prefer running it directly:

```sh
gitleaks protect --staged -v   # staged changes only, no history rewrite
```

## The reference-not-value pattern (tg)

`infrastructure/live/scripts/tg` resolves Proton Pass credentials as
`pass://Vault/Item/field` **reference strings**, not values — the actual
secret is only ever materialized inside `pass-cli run`'s child process
environment, never in `tg`'s own bash process, never printed, never written
to disk. If a diff to `tg`, `root.hcl`, or any Terragrunt/OpenTofu backend
config would cause a real value (not a `pass://` reference) to appear in:

- a shell variable that gets echoed or logged,
- a file written to disk (including a `.terragrunt-cache/**/backend.tf` —
  this exact failure mode already happened once, see `root.hcl`'s own
  comments),
- or a command's argument list (visible via `ps`),

that is a regression, not a normal finding — stop and flag it, don't try to
fix it silently.

## What "not applicable" looks like

Most tasks touch no secret material at all. Report "not applicable, no
credential/backend config touched" rather than forcing a finding — a
false-positive here erodes trust in the check faster than an occasional
skipped one.
