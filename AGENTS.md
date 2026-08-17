# Repository Guidelines

## Project Structure & Module Organization

This greenfield repository defines a zero-trust Kubernetes platform for OCI
Always Free. Consult `docs/00-overview/roadmap.md` before assuming a component
exists.

- `docs/00-overview/` describes vision and milestones.
- `docs/01-architecture/`, `docs/arch/`, and `*.mmd` files contain architecture views and Mermaid sources.
- `docs/02-decisions/` holds accepted ADRs; `docs/specs/` contains canonical numbered requirements.
- `infrastructure/` is reserved for OpenTofu modules, compositions, and Terragrunt live environments.
- `scripts/` contains validation helpers; `.github/` defines CI and PR policy.

There is no application or unit-test suite. `package.json` supports docs only.

## Build, Test, and Development Commands

- `npm ci`: install the Mermaid CLI.
- `npm run validate:mermaid`: render every `docs/**/*.mmd` file to verify syntax.
- `npx markdownlint-cli2 --config .markdownlint-cli2.yaml "docs/**/*.md" "*.md" ".github/**/*.md"`:
  lint documentation as CI does.
- `pre-commit run --all-files`: run the complete local validation gate.
- `scripts/check-gpg-signing.sh`: verify OpenPGP signing is enabled and a
  signing key is configured.
- `tofu fmt -check -recursive infrastructure`: check OpenTofu formatting.
- `tflint --recursive` and `checkov -d infrastructure`: lint and security-scan infrastructure.

Run `tofu init -backend=false && tofu validate` inside each module or
composition containing `main.tf`; root-level validation is not meaningful.

## Coding Style & Naming Conventions

Use two-space indentation for YAML and follow `tofu fmt` for HCL. Keep
Markdown lines within 120 characters, add language tags to fenced blocks, and
use compact tables. Name decisions `ADR-NNNN-topic.md`, specifications
`SPEC-<AREA>-<NNN>.md`, and requirements `REQ-<AREA>-NNN`. Preserve ownership
boundaries: OpenTofu provisions OCI, Terragrunt composes environments, Talos
configures nodes, and Flux owns Kubernetes desired state.

## Testing Guidelines

Place OpenTofu tests beside their module as `*.tftest.hcl`; CI initializes that
directory and runs `tofu test`. Validate changed Mermaid diagrams and run all
pre-commit hooks before pushing. Update architecture, threat-model, ADR, and
specification artifacts whenever trust boundaries or decisions change.

## Commit & Pull Request Guidelines

History follows Conventional Commit-style subjects such as `docs:`, `fix:`,
`refactor:`, and `chore(deps):`. Branch from `main` with `feat/`, `fix/`, or
`docs/`; never push directly to `main`. Create signed, DCO-attested commits with
`git commit -s -S`. PRs must explain why, link the relevant issue/spec/ADR,
record validation evidence and infrastructure plan impact, pass CI, and be
squash-merged.

Enable enforced local hooks once with `git config core.hooksPath .githooks`.
The pre-commit hook rejects missing GPG configuration or key IDs; the commit-msg
hook rejects missing DCO trailers; the post-commit hook rejects a HEAD commit
that isn't actually GPG-signed (catches `--no-gpg-sign` overrides that the
pre-commit config check can't see, since the commit object doesn't exist yet
at that stage).

## Security & Configuration

Never commit credentials. Use SOPS-encrypted files under `bootstrap/sops/`,
GitHub encrypted secrets, or OCI-managed secrets; rotate anything exposed
immediately.
