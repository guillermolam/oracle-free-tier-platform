# Contributing

This is a single-maintainer, mono-repo platform project. The `main` branch is the
source of truth for what is deployed. Treat every change as a reviewable unit.

## Workflow

1. Branch from `main` using a short descriptive name: `feat/`, `fix/`, `docs/`.
2. Commit with GPG-signed commits and Developer Certificate of Origin (`git commit -s -S`).
   Signing and DCO sign-off (`Signed-off-by:`) are mandatory.
3. Open a Pull Request. The PR template lists the required checks.
4. CI must pass before merging: `validate`, `security`, `docs`, `dco`, and `plan`.
5. Merge via squash.

## Ownership model

- **OpenTofu** owns OCI infrastructure.
- **Talos** owns node configuration.
- **Flux** owns Kubernetes desired state. GitHub Actions never deploy.
- **Cilium / SPIRE / OpenBao / ESO / Kyverno** own their respective control planes.

## Validation gates

Run before pushing:

```sh
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
