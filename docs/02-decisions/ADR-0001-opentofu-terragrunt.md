# ADR-0001: OpenTofu + Terragrunt for infrastructure as code

Status: Accepted

## Context

The platform needs a single IaC toolchain for OCI resources that (a) is not
subject to a vendor's licensing terms, (b) separates module logic from
per-environment composition and state boundaries, and (c) already has CI
support in this repo — `validate.yml` runs `tofu fmt`, `tofu validate`,
`tofu test`, and `tflint`; `plan.yml` runs `tofu plan` against
`infrastructure/live/`; `pre-commit-terraform` hooks are already configured
for `tofu_fmt`/`tofu_validate`/`tflint`/`checkov`.

## Decision

OpenTofu owns OCI infrastructure resource definitions
(`infrastructure/modules/`, `infrastructure/compositions/`). Terragrunt owns
environment composition, dependency orchestration between compositions, and
state boundaries (`infrastructure/live/<provider>/<region>/<env>/`). Neither
tool is responsible for Kubernetes desired state — that is Flux's boundary
(ADR-0005).

## Consequences

- Every OCI resource change goes through `tofu fmt`/`validate`/`tflint`/
  `checkov` before merge (already enforced).
- Environment-specific values (lab/staging/prod) never live inside a
  module; they live in Terragrunt `terragrunt.hcl` files under
  `infrastructure/live/`.
- State backend is an OCI Object Storage bucket per SPEC-OCI-001, not local
  state or a third-party SaaS backend.
- Ownership boundary is enforced by convention and `CODEOWNERS`
  (`infrastructure/live/` requires `@guillermolam` review), not by tooling.
