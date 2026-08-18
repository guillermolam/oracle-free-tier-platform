# Contributing

This is a single-maintainer, mono-repo platform project. The `main` branch is the
source of truth for what is deployed. Treat every change as a reviewable unit.

## Workflow

1. Install the `pre-commit` tool itself (e.g. `pipx install pre-commit` or
   `brew install pre-commit`), then enable this repository's local hooks
   once with `git config core.hooksPath .githooks` (repository-local —
   this does not touch your global git config, and does not require
   running `pre-commit install`; `.githooks/pre-commit` invokes
   `pre-commit run` directly).
2. Branch from `main` using a short descriptive name: `feat/`, `fix/`,
   `docs/`. Never push directly to `main`.
3. Commit with both DCO sign-off and cryptographic signing —
   `git commit -s -S`:
   - `-s` adds the `Signed-off-by:` trailer (DCO certification).
   - `-S` cryptographically signs the commit (OpenPGP only; requires
     `commit.gpgsign`, `user.signingkey`, and `gpg`/`gpg.program` on PATH
     — `scripts/check-gpg-signing.sh` verifies this is configured).

   These are separate controls; one does not satisfy the other. See
   [AGENTS.md](AGENTS.md#commit--pull-request-guidelines) for how DCO and
   signing are each actually verified (locally and in CI), including a
   known gap around per-commit signature enforcement.
4. Open a Pull Request. The PR template lists the required checks.
5. CI must pass before merging. `security` (secret scanning, SAST,
   workflow lint, vulnerability/IaC scan) and `dco` always run and are
   required; `validate`/`plan` only run when `infrastructure/**` changes,
   and `docs` only when `docs/**`/`*.md` changes — but they still block
   merge when they do run.
6. Merge via squash.

## Ownership model

- **OpenTofu** owns OCI resource logic (`infrastructure/modules/`);
  **Terragrunt** owns environment composition and state boundaries
  (`infrastructure/live/`) — see `infrastructure/README.md` for the
  state-unit DAG.
- **Talos** owns node configuration.
- **Flux** owns Kubernetes desired state. GitHub Actions never deploy.
- **Cilium / SPIRE / OpenBao / ESO / Kyverno** own their respective control planes.

## Validation gates

Run before pushing:

```sh
scripts/check-gpg-signing.sh
pre-commit run --all-files
npm run validate:mermaid              # if any docs/**/*.mmd changed
npm run validate:threat-model         # if docs/03-threat-model/model/** changed
terragrunt hcl fmt --check            # from infrastructure/live/, if any *.hcl changed
tofu fmt -recursive infrastructure
tflint --recursive
checkov -d infrastructure
```

Once `infrastructure/modules/` or `infrastructure/compositions/` exist, run
`tofu init -backend=false && tofu validate` inside each directory
containing `main.tf` — never an unqualified `tofu validate` from the repo
root; there's no root-level config to validate against and it produces a
false green. See [AGENTS.md](AGENTS.md#build-test-and-development-commands)
for the exact command set.

Docs, threat-model, and ADR changes must be updated when a decision or trust
boundary changes (see the PR checklist).

## Secrets policy

Never commit secrets. Use SOPS-encrypted files under `bootstrap/sops/`, GitHub
Actions encrypted secrets, or OCI-managed secrets. Anything accidental gets
rotated immediately.
