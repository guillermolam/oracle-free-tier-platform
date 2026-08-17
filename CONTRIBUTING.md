# Contributing

This is a single-maintainer, mono-repo platform project. The `main` branch is the
source of truth for what is deployed. Treat every change as a reviewable unit.

## Workflow

1. Enable repository hooks once with `git config core.hooksPath .githooks` and
   install `pre-commit`.
2. Branch from `main` using a short descriptive name: `feat/`, `fix/`, `docs/`.
3. Commit with GPG-signed commits and Developer Certificate of Origin (`git commit -s -S`).
   Signing and DCO sign-off (`Signed-off-by:`) are mandatory.
4. Open a Pull Request. The PR template lists the required checks.
5. CI must pass before merging: `validate`, `security`, `docs`, `dco`, and `plan`.
6. Merge via squash.

## Ownership model

- **OpenTofu** owns OCI infrastructure.
- **Talos** owns node configuration.
- **Flux** owns Kubernetes desired state. GitHub Actions never deploy.
- **Cilium / SPIRE / OpenBao / ESO / Kyverno** own their respective control planes.

## Validation gates

Run before pushing:

```sh
scripts/check-gpg-signing.sh
pre-commit run --all-files
tofu fmt -recursive infrastructure
tofu validate
tflint --recursive
checkov -d infrastructure
```

Docs, threat-model, and ADR changes must be updated when a decision or trust
boundary changes (see the PR checklist).

## Secrets policy

Never commit secrets. Use SOPS-encrypted files under `bootstrap/sops/`, GitHub
Actions encrypted secrets, or OCI-managed secrets. Anything accidental gets
rotated immediately.
