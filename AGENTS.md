# Repository Guidelines

## Mission

A zero-trust Kubernetes platform on OCI Always Free Tier, built entirely as
IaC + GitOps. See [docs/00-overview/vision.md](docs/00-overview/vision.md)
for the full problem statement.

## Project Structure & Module Organization

Architecture work proceeds domain-by-domain (network →
identity/governance/CI-CD → Kubernetes), evidence-first. `infrastructure/`
is no longer reserved-only: `00-foundation` (compartment, IAM, the
Terragrunt state-backend bucket) and `10-network` (VCN, 4 trust-zone
subnets, Internet Gateway, DRG object) are real modules with real,
partially-applied resources in the lab environment — NAT/Service Gateway,
DRG route tables/attachment, and per-zone route tables are still blocked
on real OCI service-limit constraints (see
`infrastructure/modules/network/README.md`'s Failure modes section), not
yet built. Consult `docs/00-overview/roadmap.md` for what milestone is
actually in progress before assuming a component exists further along
than this — do not infer that a later phase (e.g. Kubernetes bootstrap)
has started from this file.

- `docs/00-overview/` — vision, personas, roadmap.
- `docs/01-architecture/`, `docs/arch/`, and `*.mmd` files — architecture
  views and Mermaid sources (see "Architecture model" below).
- `docs/02-decisions/` — accepted ADRs.
- `docs/specs/` — canonical numbered requirements (see "Source of truth"
  below).
- `docs/03-threat-model/` — Phase 3A in progress (EPIC-TM-01/I20): a
  real, schema-validated `network.yaml` corpus exists
  (`docs/03-threat-model/model/instances/`); the DFD/STRIDE/attack-tree
  phases after it have not started — see that directory's own
  `README.md` for the exact pipeline position.
- `docs/04-operations/`, `docs/05-security/`, `docs/06-runbooks/` — not
  started yet; each has a `README.md` stating so.
- `infrastructure/` — OpenTofu modules, compositions, and Terragrunt live
  environments (see above — partially applied, not reserved-only).
- `scripts/` — validation helpers; `.github/` — CI and PR policy.

There is no application or unit-test suite. `package.json` exists solely
for docs tooling (`@mermaid-js/mermaid-cli`, pinned; used by
`.github/workflows/docs.yml`'s `mermaid` job and by
`scripts/validate-mermaid.sh`) — it is not an application package manager.

## Source of truth: Specs, ADRs, and GitHub issues

`docs/specs/SPEC-<AREA>-<NNN>.md` is the canonical, versioned record of
**what** a capability must do and **why** — numbered `REQ-*` requirements,
acceptance criteria, and Diagram/ADR/Threat-Model impact. This is the file
to read before implementing anything it governs, not the GitHub issue
title. GitHub issues (Feature / Story / Enabler / Spike) are thin execution
contracts that point at a Spec by path rather than restating it:

```text
docs/specs/SPEC-<AREA>-NNN.md   <- canonical WHAT + WHY + contract
             |
             v
     GitHub Feature/Story/Enabler/Spike   <- disposable execution tracking
             |
             v
         Pull Request  ->  Tests, ADR, Diagrams  ->  Spec verified
```

`docs/02-decisions/ADR-*.md` records decisions that are settled, not open
for re-litigation without a superseding ADR. Work is modeled as Initiatives
(I01-I25) → Epics → Specs → Stories/Enablers/Spikes, tracked through GitHub
Milestones (M0-M12) and Issues — see `docs/00-overview/roadmap.md` for the
full model and critical path. Labels follow `area/*`, `type/*`, `risk/*`,
`stage/*`, `priority/*`, `status/*` as defined in `.github/labels.yml`;
extend that taxonomy rather than inventing a parallel one.

## Architecture model (L0-L4)

One architecture, multiple viewpoints, one set of shared contracts (the
Specs). A diagram is a **projection**, not an independent source of truth —
it traces back through a stable `ARCH-*` concept ID (defined in
`docs/01-architecture/traceability.md`) rather than a volatile Mermaid node
name, decoupling Specs/Issues from diagram implementation detail. Levels:
L0 System Context, L1 Cloud Deployment, L2 Domain Architecture, L3
Component/Zone Detail, L4 Dynamic/Flow View — see
`docs/01-architecture/README.md` for the full model and navigation, and
`views.md` for the view catalog (every view's question, audience, scope,
governing Specs, status).

`mmdc` (Mermaid CLI) is the **authoritative validator** for every `.mmd`
file — an editor preview is not. Pinned in `package.json`, invoked via
`npm run validate:mermaid` (CI) or `scripts/validate-mermaid.sh` (local
pre-commit, mirrors CI including `--no-sandbox` Puppeteer config).

## Technology ownership boundaries — do not blur these

Fixed by `CONTRIBUTING.md` and recorded in `docs/02-decisions/`:

- **OpenTofu** owns OCI infrastructure resources; **Terragrunt** owns
  environment composition and state boundaries. Layout:
  `infrastructure/modules/` (resources) → `infrastructure/compositions/`
  (wiring) → `infrastructure/live/<provider>/<region>/<env>/` (Terragrunt,
  per-environment).
- **Talos** owns node configuration — no SSH, only `talosctl` /
  declarative machine config.
- **Cilium** owns Kubernetes networking/NetworkPolicy.
- **OpenZiti** owns zero-trust administrative network access — no direct
  internet path to `kube-apiserver` (ADR-0003).
- **SPIFFE/SPIRE** owns workload identity, distinct from Kubernetes
  ServiceAccounts, OCI IAM, and human IdP identity — see
  `docs/01-architecture/identity-reconciliation.md` for how (or whether)
  these principals map to each other.
- **OpenBao + External Secrets Operator** own secrets/PKI.
- **Kyverno** is the admission policy engine — not OPA/Gatekeeper
  (ADR-0004).
- **Flux** owns Kubernetes desired state. GitHub Actions never deploys to
  the cluster — CI only validates and plans (`validate.yml`, `plan.yml`).
  Any workflow change that runs `kubectl`/`helm`/`flux` against a live
  cluster contradicts ADR-0005 and should be treated as a bug, not a
  feature.

## Network / trust-zone guardrail

`docs/arch/cloud-deployment.mmd` and ADR-0006 define one VCN split into
four trust zones — Edge (only zone that may hold a public IP), Management
(control plane / `kube-apiserver`), Workload, Data. The Kubernetes API has
no direct internet path: administrator → OpenZiti public edge router
(Edge) → Ziti fabric → Ziti private router (Management) →
`kube-apiserver` (ADR-0003). Check any network change against this model,
particularly the recurring-bug invariant that port 6443 must stay
reachable from **both** the `ziti` NSG (administrative access) and the
`worker` NSG (cluster nodes — kubelet/kube-proxy need it to function),
never any other source (`SPEC-NET-004.md` REQ-NET-019).

## Build, Test, and Development Commands

- `npm ci`: install the Mermaid CLI.
- `npm run validate:mermaid`: render every `docs/**/*.mmd` file with
  `mmdc` to verify syntax (authoritative — see "Architecture model").
- `npx markdownlint-cli2 --config .markdownlint-cli2.yaml "docs/**/*.md" "*.md" ".github/**/*.md"`:
  lint documentation as CI does. Add `--fix` first — most findings are
  MD060 (tables must use the compact pipe style: `| --- | --- |`, no
  interior padding, resolved automatically by `--fix`) and MD040 (every
  fenced code block needs a language tag, not resolved by `--fix`).
- `pre-commit run --all-files`: run the complete local validation gate.
- `scripts/check-gpg-signing.sh`: verify commit signing is configured (see
  "Commit & Pull Request Guidelines").
- `scripts/check-gpg-signing.test.sh`: deterministic config-only tests for
  the above (isolated from your real `~/.gitconfig`; no real signing key
  needed). Runs automatically via pre-commit when either file changes.
- `npm run validate:threat-model`: schema + corpus-wide referential
  integrity for `docs/03-threat-model/model/instances/*.yaml`.
- `npm run test:threat-model`: the validator's own fixture-based
  self-test (no real corpus data). Run this before
  `validate:threat-model` when you've touched the validator itself.
- `terragrunt hcl fmt --check` / `terragrunt hcl validate` (run from
  `infrastructure/live/`): format-check and semantic-validate every
  Terragrunt HCL file — works even before any per-unit `terragrunt.hcl`
  exists, since it validates the shared `root.hcl`/`common/*.hcl`
  composition layer directly. See `infrastructure/README.md` for the
  state-unit layout these compose.
- `tofu fmt -recursive infrastructure`, `tflint --recursive`,
  `checkov -d infrastructure`, and — critically — validate each
  configuration directory individually, never from the repo root, once
  `infrastructure/modules/` or `infrastructure/compositions/` exist: `cd`
  into each directory containing `main.tf`, run
  `tofu init -backend=false`, then `tofu validate`; also run `tofu test`
  in any directory containing `*.tftest.hcl`. This matches
  `.github/workflows/validate.yml`'s actual loop — an unqualified
  `tofu validate` from the repository root validates nothing useful once
  modules exist and gives a false green.

When adding or modifying a GitHub Actions workflow, verify the current
upstream version/SHA of any `uses:` action from its official repository
before pinning it — do not rely on a remembered or guessed version.

## Coding Style & Naming Conventions

Use two-space indentation for YAML and follow `tofu fmt` for HCL. Keep
Markdown lines within 120 characters, add language tags to fenced blocks,
and use compact tables. Name decisions `ADR-NNNN-topic.md`, specifications
`SPEC-<AREA>-<NNN>.md`, and requirements `REQ-<AREA>-NNN`.

## Testing Guidelines

Place OpenTofu tests beside their module as `*.tftest.hcl`; CI initializes
that directory and runs `tofu test`. Validate changed Mermaid diagrams and
run all pre-commit hooks before pushing. Update architecture, threat-model,
ADR, and specification artifacts whenever trust boundaries or decisions
change — a Spec's Diagram/ADR/Threat-Model Impact fields say which.

## Commit & Pull Request Guidelines

History follows Conventional Commit-style subjects such as `docs:`, `fix:`,
`refactor:`, and `chore(deps):`. Branch from `main` with `feat/`, `fix/`,
or `docs/`; never push directly to `main`.

DCO and cryptographic signing are **separate controls** — do not treat one
as satisfying the other:

- **DCO** (`Signed-off-by:` trailer, added by `git commit -s`) certifies
  you have the right to submit the change under the Developer Certificate
  of Origin. Enforced per-original-commit by `.github/workflows/dco.yml`
  (a required status check) and locally by `.githooks/commit-msg`.
- **Commit signing** (`git commit -S`, OpenPGP only — `gpg.format=ssh`/
  `x509` is rejected) cryptographically authenticates the commit. GitHub's
  branch protection has "Require signed commits" enabled on `main`, but
  since this repo squash-merges exclusively, that native check is
  satisfied by GitHub's own auto-signed web-flow commit regardless of
  whether your original commits were signed — it does **not** currently
  give authoritative, CI-enforced proof that your local commits were
  signed. The only check for that today is local: `scripts/check-gpg-signing.sh`
  (via `.pre-commit-config.yaml`'s `check-gpg-signing` hook, pre-commit
  stage) verifies signing is *configured*, and `.githooks/post-commit`
  verifies the commit just made was *actually* signed (catches
  `--no-gpg-sign` overrides that a pre-commit config check can't see,
  since the commit object doesn't exist yet at that stage). Both commands
  are required together: `git commit -s -S`.

Enable enforced local hooks once with `git config core.hooksPath
.githooks` (repository-local; this never touches global git config) and
install `pre-commit` (`pre-commit install` is not required — the
`.githooks/pre-commit` hook invokes `pre-commit run` directly).

PRs must explain why, link the relevant issue/spec/ADR, record validation
evidence and infrastructure plan impact, pass CI, and be squash-merged.
Required status checks on `main`: `Secret scanning (gitleaks)`,
`SAST (Semgrep)`, `Workflow lint (zizmor)`,
`Vulnerability and IaC scan (Trivy)`, `Developer Certificate of Origin
(DCO)`. `validate`/`plan` are path-filtered to `infrastructure/**`, and
`docs` to `docs/**`/`*.md` — they only run, and only block merge, when
those paths are touched. Required PR-approval count is intentionally 0:
this is a single-maintainer repo, a PR is still mandatory, it's just not
gated on a second reviewer who doesn't exist here.

## Security & Configuration

Never commit credentials, `.oci/` material, Talos secrets, kubeconfigs,
`.env` files, or unencrypted SOPS files. Use SOPS-encrypted files under
`bootstrap/sops/`, GitHub encrypted secrets, or OCI-managed secrets;
rotate anything exposed immediately. See `SECURITY.md` for the
vulnerability-reporting process.

### Terragrunt/OpenTofu remote-state backend credentials

Full operator procedure (prerequisites, usage, troubleshooting,
rotation, migration path):
[infrastructure/README.md#secrets-and-credentials-strategy](infrastructure/README.md#secrets-and-credentials-strategy)
— this is the canonical document; the rules below are the operational
contract an agent must follow, not a restatement of that procedure.

- Local backend credentials (the OCI Customer Secret Key, exposed as
  `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` — S3-client-mandated
  names, not AWS account credentials) come from **Proton Pass** only:
  vault `Personal`, item `OCI - OpenTofu Remote State v3`
  (`username` → Access Key ID, `password` → Secret Key).
- **`infrastructure/live/scripts/tg` is the only supported entry
  point** for local `terragrunt`/`tofu` invocations against real OCI —
  never run `terragrunt`/`tofu` directly against a unit whose backend
  needs this credential.
- Never request, print, log, persist, copy, or inspect the secret
  value. Never run `pass-cli item view` for this item with
  `--output human` or without piping into a values-stripping filter.
- Never place these credentials in HCL, `.env` files, shell profiles,
  `~/.aws/credentials`, `~/.aws/config`, repository files, generated
  `backend.tf`, plan artifacts, or logs.
- Never bypass `tg` by manually exporting these credentials, and never
  silently fall back to AWS profiles, AWS SSO, plaintext files, or
  macOS Keychain — macOS Keychain is explicitly **not** a supported
  credential source for this repository, for anyone, with no
  exceptions (this predates and extends beyond this specific
  credential).
- Fail closed when Proton Pass retrieval or OCI namespace resolution
  fails — do not improvise an alternate source.
- Never rotate or delete an OCI Customer Secret Key as part of normal
  validation or automated cleanup. Rotation/deletion requires explicit
  user authorization (see the README's rotation procedure).
- **Proton Pass is a bootstrap/local-development mechanism, not this
  platform's final-state secret architecture.** Secret ownership is
  expected to move to OpenBao (already the roadmap target,
  `docs/00-overview/roadmap.md`) once it is deployed and reachable from
  wherever Terragrunt/OpenTofu runs. Do not introduce a new permanent
  dependency on Proton Pass beyond this bootstrap role, and design any
  new secret-handling code so the source can later swap to OpenBao
  without changing Terragrunt/OpenTofu module contracts — see `tg`'s
  own `run_with_backend_credentials()` for the established pattern.
- Preserve remote-state safety before any plan/apply/import/state
  operation: check `git status`, confirm the working directory is
  clean, and never run a mutating state operation without first
  understanding what's currently applied.

## Agent-specific guardrails

- Never revert, overwrite, stage, reformat, or rename a user's own
  uncommitted or in-progress work to unblock an unrelated operation (e.g.
  a branch checkout). Stash it (`git stash -u` for untracked files too)
  and restore it afterward instead.
- Run `git status` before any operation that could discard uncommitted
  work (`checkout`/`restore`/`reset`/`clean` and similar).
- Never force-push `main`. Prefer rebase over merge when updating a PR
  branch against `main`, to avoid an unsigned/un-DCO'd merge commit.
- Do not begin a new architecture or threat-modeling phase (DFDs, attack
  trees, IriusRisk, IAM/PAM/JIT/JEA) without an explicit go-ahead — each
  phase in this program is started deliberately, not inferred from
  "what's next" in the roadmap.
- Treat automated review-bot billing/paywall notices (e.g. "trial
  expired", "reviews paused for this user") as non-actionable noise, not
  findings — but still read every review for genuine findings underneath.
- Always use `infrastructure/live/scripts/tg` for local
  `terragrunt`/`tofu` against real OCI — never invoke them directly, and
  never manually export the OCI Customer Secret Key as a bypass. See
  "Terragrunt/OpenTofu remote-state backend credentials" above.
