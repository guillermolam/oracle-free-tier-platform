# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A zero-trust Kubernetes platform on OCI Always Free Tier, built entirely as
IaC + GitOps. It is currently **greenfield**: governance scaffolding, docs,
and specs exist, but no OpenTofu modules or running infrastructure yet.
Check `docs/00-overview/roadmap.md` for what milestone is actually in
progress before assuming a component exists.

## Commands

- Full validation gate (run before pushing): `pre-commit run --all-files`
- OpenTofu, once `infrastructure/modules/` or `infrastructure/compositions/`
  exist: `tofu fmt -recursive infrastructure`, `tflint --recursive`,
  `checkov -d infrastructure`, and, **per module/composition directory**
  (there's no root-level config to validate against): `cd` into each
  directory containing `main.tf`, `tofu init -backend=false`, then
  `tofu validate` — and `tofu test` for any directory containing
  `*.tftest.hcl` (mirrors `.github/workflows/validate.yml`'s actual loop;
  running `tofu validate` unqualified from the repo root validates nothing
  useful once modules exist).
- Markdown lint, matching CI (`.github/workflows/docs.yml`):
  `npx markdownlint-cli2 --config .markdownlint-cli2.yaml "docs/**/*.md" "README.md" "SECURITY.md" "CONTRIBUTING.md" ".github/**/*.md"`.
  Add `--fix` first — most findings are MD060 (tables must use the
  *compact* pipe style: `| --- | --- |`, no interior padding) and MD040
  (every fenced code block needs a language tag, e.g. `bash` or `text`);
  `--fix` resolves MD060 automatically but not MD040.
- Commits **must** be GPG-signed and DCO-attested: `git commit -s -S`.
  Only the DCO trailer is actually verified by tooling — both
  `.githooks/commit-msg` and `.github/workflows/dco.yml` check for a
  `Signed-off-by:` line, not a valid GPG signature. GPG signing is a repo
  convention enforced by discipline (and by GitHub's own commit-signature
  UI), not by either of those checks.
- There is no application code or test suite yet — don't invent
  `npm test` / `make build` / similar. `package.json` exists solely for
  `docs/` tooling (`@mermaid-js/mermaid-cli`, pinned and used by
  `docs.yml`'s `mermaid` job and this repo's pre-commit hook) — it is not
  an application package manager.

## How work is specified (read this before implementing anything)

This repo deliberately separates the durable specification from disposable
execution tracking — see `docs/specs/README.md` for the full contract:

- `docs/specs/SPEC-<AREA>-<NNN>.md` is the canonical, versioned record of
  **what** a capability must do and **why** — numbered `REQ-*` requirements,
  acceptance criteria, security/threat-model/ADR impact. This is the file to
  read before implementing anything it governs, not the GitHub issue title.
- GitHub issues (Feature / Story / Enabler / Spike) are thin execution
  contracts that point at a Spec by path rather than restating it. A
  Story's "Read First" section names the exact Spec and requirement IDs.
- `docs/02-decisions/ADR-*.md` records decisions that are settled, not open
  for re-litigation without a superseding ADR (see below for what's already
  decided).

## Technology ownership boundaries — do not blur these

Fixed by `CONTRIBUTING.md` and recorded in `docs/02-decisions/`:

- **OpenTofu** owns OCI infrastructure resources; **Terragrunt** owns
  environment composition and state boundaries. Layout:
  `infrastructure/modules/` (resources) → `infrastructure/compositions/`
  (wiring) → `infrastructure/live/<provider>/<region>/<env>/` (Terragrunt,
  per-environment).
- **Talos** owns node configuration — no SSH, only `talosctl` / declarative
  machine config.
- **Flux** owns Kubernetes desired state. GitHub Actions never deploys to
  the cluster — CI only validates and plans (`validate.yml`, `plan.yml`).
  Any workflow change that runs `kubectl`/`helm`/`flux` against a live
  cluster contradicts ADR-0005 and should be treated as a bug, not a feature.
- **Cilium / SPIRE / OpenBao / External Secrets Operator / Kyverno** own
  their respective control planes. Kyverno is the policy engine — not
  OPA/Gatekeeper (ADR-0004).

## Network / trust-zone model

`docs/arch/cloud-deployment.mmd` and ADR-0006 define one VCN
(`10.10.0.0/16`) split into four trust zones: Edge (`10.10.10.0/24` — the
only zone that may hold a public IP), Management (`10.10.20.0/24` —
control plane and `kube-apiserver`), Workload (`10.10.30.0/24`), Data
(`10.10.40.0/24`). The Kubernetes API has **no direct internet path**: the
only route in is administrator → OpenZiti public edge router (Edge) → Ziti
fabric → Ziti private router (Management) → `kube-apiserver` (ADR-0003).
`SPEC-NET-001` through `SPEC-NET-004` implement this zone by zone — check
any network change against this model, particularly the "no public IP
outside Edge" and "port 6443 reachable only from the `ziti` NSG
(administrative access) and the `worker` NSG (cluster nodes — kubelet and
kube-proxy must reach `kube-apiserver` to function), never any other
source" invariant (`SPEC-NET-004.md` REQ-NET-019).

## Planning system

Work is modeled as Initiatives (I01–I25) → Epics → Specs → Stories /
Enablers / Spikes, tracked through GitHub Milestones (M0–M12) and Issues —
see `docs/00-overview/roadmap.md` for the full model and critical path.
Labels follow `area/*`, `type/*`, `risk/*`, `stage/*`, `priority/*`,
`status/*` as defined in `.github/labels.yml`; extend that taxonomy rather
than inventing a parallel one.

## Branch / PR requirements

Single-maintainer repo. Never push directly to `main` — branch protection
requires a PR with signed + DCO commits and the `security` job set
(gitleaks/semgrep/zizmor/trivy) plus `dco` green. `validate` and `plan` are
path-filtered to `infrastructure/**`, and `docs` to `docs/**`/`*.md`, so
they only run (and only block merge) when those paths are touched. Required
PR-approval count is intentionally 0 — a PR is still mandatory, it's just
not gated on a second reviewer who doesn't exist on this repo.
