# `foundation` module

## Purpose

Implements `SPEC-OCI-001` (REQ-OCI-001..007): the root of the platform's
dependency graph. Every other module needs this one applied first — it
creates the compartment everything else lives in, the Defined Tags
taxonomy other modules apply values from, the least-privilege IAM policies
scoping CI/admin access, and the OCI Object Storage bucket every
Terragrunt unit (including this one, after bootstrap) stores state in.
This is a single module — not split further — because ADR-0007 already
decided `00-foundation` is one state unit: these resources share one
blast radius (everything downstream depends on the compartment existing)
and one lifecycle (essentially create-once).

## Input contract

| Variable | Type | Required | Validation |
| --- | --- | --- | --- |
| `tenancy_ocid` | string | yes | must match `^ocid1\.tenancy\.` |
| `compartment_name` | string | no (default `"platform"`) | — |
| `compartment_description` | string | no | — |
| `environment` | string | yes | one of `lab`, `staging`, `prod` |
| `platform_name` | string | no (default `"oracle-free-tier-platform"`) | — |
| `ci_group_name` | string | yes | non-empty |
| `admin_group_name` | string | yes | non-empty |
| `state_bucket_name` | string | yes | valid OCI bucket name pattern |
| `dynamic_group_name` | string | no (default `"platform-instances"`) | — |
| `create_dynamic_group` | bool | no (default `false`) | — |

`ci_group_name`/`admin_group_name` reference **existing** OCI IAM Groups —
this module does not create IAM Users or Groups (see "Security invariants"
below for why).

## Output contract

| Output | Consumed by |
| --- | --- |
| `compartment_ocid` | every downstream module (`SPEC-NET-001`, `SPEC-OCI-002`, `SPEC-OCI-003` Interfaces sections) |
| `compartment_name` | downstream IAM policy statements referencing the compartment by name |
| `tag_namespace_platform` / `tag_namespace_security` | downstream modules building `"<Namespace>.<Key>"` `defined_tags` references |
| `dynamic_group_ocid` | I04 (compute), once it exists; `null` while `create_dynamic_group` is `false` (default) |
| `state_bucket_name` / `state_bucket_namespace` | `infrastructure/live/root.hcl`'s backend config (must match `common/account.hcl`) |

## Resource ownership

`oci_identity_compartment` (1), `oci_identity_tag_namespace` (2:
Platform, Security), `oci_identity_tag` (4: Platform.Environment,
Platform.System, Platform.ManagedBy, Security.TrustZone),
`oci_identity_policy` (2: CI, admin), `oci_identity_dynamic_group` (0 or
1, gated by `var.create_dynamic_group` — see Security invariants),
`oci_objectstorage_bucket` (1: state), `data.oci_objectstorage_namespace`
(1, read-only).

**Not owned here**: IAM Users/Groups (see Security invariants), the
tenancy-level bootstrap-identity grant (see Bootstrap runbook), any
backup bucket (I19/M9 — a separate resource in a separate module, never
sharing the state bucket).

## Security invariants

- **REQ-OCI-001**: every resource's `compartment_id` is either
  `var.tenancy_ocid` (only for the compartment itself and the dynamic
  group, which OCI's data model requires to be tenancy-scoped) or
  `oci_identity_compartment.platform.id` — never a resource placed
  directly in the tenancy root that could instead live in the platform
  compartment.
- **REQ-OCI-002**: every `oci_identity_policy` statement targets
  `compartment ${oci_identity_compartment.platform.name}` — grep the
  module for the literal string `in tenancy` to confirm none exists.
  Statements also enumerate specific resource-type families
  (`compartments`, `tag-namespaces`, `dynamic-groups`, `policies`,
  `object-family`) rather than `all-resources` — an initial draft of the
  CI policy used `read all-resources`, which technically stayed
  compartment-scoped but would have silently broadened CI's read access
  to every future resource type added to the compartment without this
  module's own PR ever reviewing that expansion; both are enforced by
  `tests/foundation.tftest.hcl`.
- **No IAM User/Group creation**: `ci_group_name`/`admin_group_name` are
  inputs referencing pre-existing groups, not resources this module
  creates. Rationale: the OCI user `plan.yml`'s existing static secrets
  authenticate as already exists and already belongs to *some* group
  (created out-of-band, before this repo's IaC existed) — this module's
  job is granting that existing identity compartment-scoped rights, not
  managing tenancy-wide identity lifecycle, which is a broader
  identity-governance concern this Spec explicitly scopes out.
- **State bucket**: `access_type = "NoPublicAccess"` set explicitly (not
  relying on the provider default), `versioning = "Enabled"` (REQ-OCI-005),
  `lifecycle { prevent_destroy = true }`. Checkov (`validate.yml`,
  `soft_fail: false`) is the second, independent layer catching an
  accidental public-access misconfiguration.
- **Compartment**: `enable_delete = false` explicit (matches the
  provider's own default, made explicit rather than implicit — see
  `compartment.tf`'s comment) plus `lifecycle { prevent_destroy = true }`.
- **No circular tag dependency**: the compartment resource intentionally
  has no `defined_tags` (only `freeform_tags`) — see `compartment.tf`'s
  comment for why referencing a tag namespace created inside itself would
  be circular.

## Validation

```sh
cd infrastructure/modules/foundation
tofu fmt -check
tofu init -backend=false -input=false
tofu validate
tofu test
```

## Failure modes

- **Partial apply mid-bootstrap**: if phase 1 (below) fails after creating
  the compartment but before the state bucket, re-running `tofu apply`
  against the same local state is safe — OpenTofu reconciles from what
  already exists (no resource in this module has a dependency ordering
  that would leave orphaned state on a partial failure).
- **`ci_group_name`/`admin_group_name` referencing a nonexistent OCI
  Group**: `tofu apply` fails cleanly with an OCI 404 on the policy
  resource — no partial policy is left in an inconsistent state, since
  policy statements are validated as a whole by the OCI API.
- **Dynamic Group matching zero instances (M1, always, until M2)**: not a
  failure — expected and documented (`iam.tf`'s comment).

## Upgrade expectations

Changing `compartment_name` or `state_bucket_name` after first apply
forces replacement (OCI compartment/bucket names are immutable) — this is
destructive and MUST NOT be done casually; see Bootstrap runbook's
Rollback section. Changing `ci_group_name`/`admin_group_name` updates the
existing policy's statements in place (no replacement). Changing
`environment` updates the `Platform.Environment` tag value in place.

## Bootstrap runbook (REQ-OCI-007)

**This is a one-time, explicitly-labeled operation per environment, run
manually by the human administrator — never a CI step.** `plan.yml`/
`validate.yml` never execute this sequence.

This module deliberately declares **no backend block** (see
`versions.tf`'s comment) — Terragrunt's `generate` mechanism owns that
once a unit exists (`live/root.hcl`). A `backend "s3" {}` block in this
module too would be a **second** backend declaration in the same
configuration; OpenTofu rejects that outright ("Duplicate backend
configuration"), confirmed by reproducing it locally against a real
`backend.tf`, not assumed. So bootstrap runs against an **untracked
scratch copy** of this module, never the module in place — that copy is
the only place a temporary `backend.tf` is ever written.

### Phase 1 — local bootstrap apply (scratch copy)

```sh
cp -r infrastructure/modules/foundation /tmp/foundation-bootstrap
cd /tmp/foundation-bootstrap
rm -rf tests examples .terraform .terraform.lock.hcl

tofu init -input=false   # no backend declared -> defaults to local ./terraform.tfstate
tofu apply -input=false \
  -var="tenancy_ocid=$OCI_TENANCY_OCID" \
  -var="environment=lab" \
  -var="ci_group_name=<existing CI group name>" \
  -var="admin_group_name=<existing admin group name>" \
  -var="state_bucket_name=oracle-free-tier-platform-tfstate"
```

Creates: the compartment, both tag namespaces + 4 tags, both IAM
policies, the dynamic group, and — critically — the state bucket itself.

### Phase 2 — write the real backend and migrate (same scratch copy)

```sh
# Still in /tmp/foundation-bootstrap. A real, complete backend block --
# not partial -backend-config flags into a pre-declared empty block,
# since none exists anymore.
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket = "oracle-free-tier-platform-tfstate"
    key    = "oci/eu-madrid-1/lab/00-foundation/terraform.tfstate"
    region = "eu-madrid-1"

    endpoints = {
      s3 = "https://\$OCI_OBJECT_STORAGE_NAMESPACE.compat.objectstorage.eu-madrid-1.oci.customer-oci.com"
    }

    # access_key/secret_key are read natively from AWS_ACCESS_KEY_ID/
    # AWS_SECRET_ACCESS_KEY (the Customer Secret Key -- see below) --
    # never written into this file.
    use_path_style               = true
    skip_region_validation       = true
    skip_credentials_validation  = true
    skip_metadata_api_check      = true
    skip_s3_checksum             = true
  }
}
EOF

tofu init -input=false -migrate-state
```

OpenTofu detects the backend configuration changed (none → `s3`) and,
with `-migrate-state`, copies the local `terraform.tfstate` into the
bucket at the key above without prompting.

### Verify, then discard the scratch copy

```sh
oci iam compartment list --compartment-id-in-subtree true \
  --query "data[?name=='platform']"
oci os object list --bucket-name oracle-free-tier-platform-tfstate \
  --namespace "$OCI_NS" --query "data[?starts_with(name, 'oci/eu-madrid-1/lab/00-foundation/')]"

# Confirm the object above exists in the bucket BEFORE this step --
# nothing here was ever tracked in git, so there's no repo cleanup, just
# removing the local scratch directory.
rm -rf /tmp/foundation-bootstrap
```

### Every subsequent unit

`infrastructure/live/oci/eu-madrid-1/lab/00-foundation/terragrunt.hcl`
(created alongside this module, see `examples/minimal/`) includes
`root.hcl` normally from its first `terragrunt init` — the bucket already
exists by the time that unit is ever touched, so it resolves the same
backend key (`oci/eu-madrid-1/lab/00-foundation/terraform.tfstate`) this bootstrap converged
on, with no further migration needed. Every other unit (`10-network`,
`20-security/*`) uses the remote backend from its own first apply — no
bootstrap required, this module's bucket already exists.

### Customer Secret Key

The S3-Compatibility API authenticates via a Customer Secret Key (Access
Key/Secret Key pair) — **not** the OCI API key (tenancy/user OCID +
fingerprint + private key) `plan.yml`'s existing secrets use.

- **Created**: OCI Console → Identity → Users → (the CI/bootstrap user) →
  Customer Secret Keys → Generate Secret Key. The secret is shown once.
- **Local development**: export `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`
  in your shell (never in a committed file — see
  `.gitignore`/`scripts/check-gpg-signing.sh`-adjacent secrets discipline
  in `SECURITY.md`).
- **GitHub Actions**: add as encrypted repository secrets, exposed to
  `plan.yml`/future `apply` workflows as the same env var names.
- **Rotation**: generate a new key, update the secret store (local env /
  GitHub secret), verify a `terragrunt plan` succeeds, then delete the old
  key from OCI Console. No overlap-free rotation exists for a single
  active key — a brief dual-key window during rotation is expected.
- **Revocation**: delete the key from OCI Console → Users → Customer
  Secret Keys immediately if exposed; rotate per above.

### Bootstrap-identity requirement (not granted by this module)

The identity running Phase 1 needs **tenancy-level** rights to create a
compartment and an Object Storage bucket — this module's own IAM policies
(compartment-scoped, by REQ-OCI-002) cannot grant the rights needed to
create the compartment they're scoped to; that would be circular. This
tenancy-level grant must already exist on the bootstrap identity before
Phase 1 runs (via OCI Console/CLI, out-of-band — not something any
`tofu apply` in this repo creates, matching
`infrastructure/README.md#iam-bootstrap-model`'s "Bootstrap identity"
class). Minimum rights: `manage compartments in tenancy`,
`manage tag-namespaces in tenancy` (or compartment-scoped, if the tag
namespaces were instead created directly under the new compartment — see
`tags.tf`, which they are), `manage object-family in tenancy` (bucket
creation).

### Rollback / recovery

Compartment/bucket names are immutable (Upgrade expectations, above) —
there is no in-place rename. Recovering from a bad bootstrap means: fix
the module code, `tofu destroy` is **not** an option (`prevent_destroy`
on both the compartment and the bucket, and `enable_delete = false` on
the compartment specifically means destroy wouldn't even delete the real
resource) — the safe path is a new PR correcting the module and a fresh
`tofu apply` reconciling forward, per `SPEC-OCI-001`'s own
Rollback/Recovery section ("never a manual console edit").

## Example

See `examples/minimal/`.

## Tests

See `tests/` — `foundation.tftest.hcl` (positive: valid inputs produce
the expected plan shape) and `foundation_negative.tftest.hcl` (invalid
environment, empty group names, invalid bucket name — each MUST fail
`tofu test`'s `expect_failures` assertions on the variable validation
blocks).
