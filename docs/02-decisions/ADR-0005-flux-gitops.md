# ADR-0005: Flux as the sole Kubernetes GitOps controller

Status: Accepted

## Context

`CONTRIBUTING.md` states this as a hard rule: "Flux owns Kubernetes desired
state. GitHub Actions never deploy." `plan.yml` only ever runs `tofu plan`
against OCI infrastructure — no workflow in `.github/workflows/` runs
`kubectl apply`, `helm install`, or any cluster mutation. This ADR exists so
that constraint is discoverable as a decision, not just an absence.

## Decision

Flux (source-controller, kustomize-controller, helm-controller) is the only
system permitted to reconcile Kubernetes desired state from Git. All
Kubernetes-targeting manifests live under `platform/` (reserved for
`@guillermolam` review per `CODEOWNERS`) and are reconciled by Flux running
inside the cluster — never applied from CI, a laptop, or any out-of-cluster
automation. Argo Rollouts/Events (I13) run as Flux-reconciled workloads
themselves; they do not become a second reconciliation path.

## Consequences

- GitHub Actions' role is strictly validate + plan + gate, never deploy —
  any future workflow that runs `kubectl`/`helm`/`flux` against a live
  cluster is a violation of this ADR and must be rejected in review.
- Cluster drift is Flux's own reconciliation loop's problem to report
  (EPIC-FLUX-03), not something CI polls for.
- Emergency manual intervention (`kubectl apply` by a human, out of band)
  is a documented, audited exception path — tracked under I24 runbooks, not
  the default.
