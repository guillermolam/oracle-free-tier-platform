# OpenTofu module contract

Every module under `infrastructure/modules/` follows this contract. No
module exists yet — this is the standard the first module (`oci-foundation`,
implementing `SPEC-OCI-001`) is held to, not a retrospective description.

## Principles

Composable, narrowly cohesive, environment-neutral, typed, validated,
documented, testable, security-conscious. A module owns OCI resource
logic; it never contains environment-specific constants, hard-coded
OCIDs, or hard-coded credentials — those are Terragrunt `live/` inputs.

Avoid: mega-modules covering more than one Terragrunt state unit's worth
of resources (state boundaries are decided in
[../README.md](../README.md#state-dag) — a module's scope should match
its state unit, not exceed it); pass-through wrappers with no
architectural value; provider configuration hidden inside a child module
(providers are configured once, at the `live/` composition layer, never
inside a reusable module); implicit cross-module dependencies not
expressed as explicit `variable`/`output` contracts.

## Required file layout

```text
modules/<name>/
├── README.md         PURPOSE, INPUT/OUTPUT contract, security invariants,
│                       failure modes, upgrade expectations (see below)
├── main.tf            resources
├── variables.tf        typed inputs, validation blocks
├── outputs.tf           outputs consumed by other units/modules
├── versions.tf            required_providers, required_version
├── locals.tf               (only if genuinely needed — don't create an
│                             empty file to satisfy this list)
├── data.tf                  (only if the module reads existing OCI state)
├── tests/
│   └── *.tftest.hcl          unit/contract tests, including negative tests
└── examples/
    └── minimal/                a runnable example with placeholder inputs
```

Don't create empty files to satisfy aesthetics — `locals.tf`/`data.tf`
exist in this list because most modules will need them, not because every
module must have every file.

## Module `README.md` must define

- **Purpose** — one paragraph, what this module owns and why it's a
  separate module (tie back to the state-DAG rationale in
  [../README.md](../README.md#state-dag)).
- **Input contract** — every variable, its type, whether required,
  validation rules applied.
- **Output contract** — every output, what consumes it (name the
  downstream module/unit).
- **Resource ownership** — the exact OCI resource types this module
  creates; nothing implicit.
- **Security invariants** — the specific guarantees this module's
  `variable` validation blocks and/or resource arguments enforce (e.g.
  "no subnet in this module can set `prohibit-public-ip-on-vnic = false`
  except when `zone == \"edge\"`").
- **Validation** — how to run `tofu validate`/`tflint`/`tofu test` for
  this module specifically.
- **Failure modes** — what a partial/failed apply leaves behind, and
  whether it's safe to re-run.
- **Upgrade expectations** — what changing an existing input does
  (in-place update vs. forces-replacement), called out per variable where
  destructive.
- **Example** — a working reference to `examples/minimal/`.
- **Tests** — what `tests/*.tftest.hcl` actually asserts, in prose.

## Validation blocks — what to encode, what not to

Use `variable` validation blocks for this repository's own invariants:

- CIDR structure and the approved network contract (10.10.0.0/16 and its
  four /24s — see [../README.md](../README.md)'s traceability matrix).
- Allowed trust-zone names (`edge`, `management`, `workload`, `data` —
  nothing else).
- No public IP on Management/Workload/Data (REQ-NET-003) — enforced at
  the module boundary, not left to composition-time discipline
  (`SPEC-NET-001`'s own Security Requirements section demands this).
- Required tags present (per [../README.md](../README.md#tagging-contract)).
- Allowed environment values (currently only `lab` exists).

Do **not** re-validate provider behavior OCI/the `oracle/oci` provider
already strongly validates upstream (e.g. don't hand-roll OCID format
checking — the provider rejects a malformed OCID on `apply` already;
duplicating that in a `validate` block adds no real invariant).

## Testing

`tofu test` (`.tftest.hcl`) covers module invariants and negative tests —
see the master execution prompt's negative-testing examples (public IP on
a private zone, workload routed directly to IGW, missing mandatory tags,
overlapping CIDR, invalid environment — each MUST FAIL). Every
security-sensitive module needs at least one negative test; happy-path-only
coverage is insufficient for a module implementing a `SPEC-NET-004`-class
security requirement.

## Candidate first modules

Proposed, not accepted — each name is confirmed or revised in the PR that
actually scaffolds it:

| Candidate name | Spec | State unit |
| --- | --- | --- |
| `oci-foundation` | SPEC-OCI-001 | `00-foundation` |
| `oci-network` | SPEC-NET-001/002/003/004/006 | `10-network` |
| `oci-kms` | SPEC-OCI-002 | `20-security/kms` |
| `oci-logging-monitoring` | SPEC-OCI-003 | `20-security/logging-monitoring` |

`oci-network` bundles VCN/subnets/gateways/routing/NSGs/DNS into one
module because ADR-0007 already decided `10-network` is one state unit —
a module boundary narrower than its state unit would just add internal
plumbing with no independent-apply benefit; a module boundary wider than
its state unit isn't possible (Terragrunt wires exactly one module source
per unit). This does not preclude internal file organization within
`oci-network/main.tf` mirroring each Spec (vcn.tf, subnets.tf, gateways.tf,
routing.tf, security.tf, dns.tf) for readability — only the Terragrunt/
state boundary is fixed, not the internal file layout.
