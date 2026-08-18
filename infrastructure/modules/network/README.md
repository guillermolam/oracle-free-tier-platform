# `network` module

## Purpose

Implements `SPEC-NET-001` (REQ-NET-001..005): the platform VCN and its
four trust-zone subnets (Edge, Management, Workload, Data), as decided by
`ADR-0006`. This is the second module in the state DAG — every downstream
network Spec (`SPEC-NET-002` gateways, `SPEC-NET-003` route tables,
`SPEC-NET-004` NSGs/Security Lists, `SPEC-NET-006` DNS/DHCP) and I04
(compute) attach to the VCN/subnets this module creates. `ADR-0007`
already decided `10-network` is one state unit covering all of
`SPEC-NET-001` through `SPEC-NET-006` — this module is built incrementally
across PRs against that same eventual state unit (this PR: `vcn.tf` +
`subnets.tf` only; a later PR adds `gateways.tf`/`routing.tf`/
`security.tf`/`dns.tf`), per `../README.md`'s own documented internal-
file-organization note. Not a further-split target: OCI network topology
within one VCN is provisioned and changed as a unit in practice.

## Input contract

| Variable | Type | Required | Validation |
| --- | --- | --- | --- |
| `compartment_ocid` | string | yes | must match `^ocid1\.compartment\.` |
| `environment` | string | yes | one of `lab`, `staging`, `prod` |
| `platform_name` | string | no (default `"oracle-free-tier-platform"`) | — |

No CIDR variables. REQ-NET-001/REQ-NET-002 mandate exact values, and
ADR-0006 is explicit they're fixed absent a superseding ADR — see
`vcn.tf`'s locals and `variables.tf`'s comment for why these are
hardcoded constants, not tunables.

## Output contract

| Output | Consumed by |
| --- | --- |
| `vcn_id` | `SPEC-NET-002` (gateways), `SPEC-NET-003` (route tables), `SPEC-NET-004` (NSGs/Security Lists) |
| `vcn_cidr` | downstream modules needing the VCN's own range (e.g. future DRG peering, I21) |
| `subnet_ids` | map keyed by zone (`edge`/`management`/`workload`/`data`) — `SPEC-NET-002`/`SPEC-NET-004`/I04 attach resources to specific subnets by zone |
| `subnet_cidrs` | map keyed by zone — downstream Security List/NSG rules referencing zone ranges |

## Resource ownership

`oci_core_vcn` (1), `oci_core_subnet` (4, one per trust zone, via
`for_each`).

**Not owned here**: gateways (Internet/NAT/Service/DRG — `SPEC-NET-002`),
route tables/associations (`SPEC-NET-003`), NSGs/Security Lists
(`SPEC-NET-004`), DNS/DHCP options (`SPEC-NET-006`), compute attachment
(I04). Subnets use OCI's auto-created default route table (empty — no
gateway routes exist yet) and default security list until those Specs'
files are added to this same module.

## Security invariants

- **REQ-NET-001**: exactly one VCN, CIDR `10.10.0.0/16` (`vcn.tf`'s
  `local.vcn_cidr`) — hardcoded, not derived from a variable, so no
  environment can silently diverge from ADR-0006's agreed range.
- **REQ-NET-002**: exactly four subnets, each with the exact CIDR
  ADR-0006's table specifies (`local.subnet_cidrs`) — cross-checked
  against `docs/arch/cloud-deployment.mmd` before writing this module,
  not assumed to match.
- **REQ-NET-003/004**: `prohibit_public_ip_on_vnic` is `true` for every
  zone except `edge` (`subnets.tf`'s `local.subnet_public_allowed`) —
  `tests/network.tftest.hcl` asserts this per zone, not just for one
  representative subnet.
- **CIDR self-check**: `vcn.tf`'s `check "trust_zone_cidrs_are_valid_and_disjoint"`
  block validates the locals themselves at plan/apply time — every CIDR
  is syntactically valid (`can(cidrhost(...))`), every subnet CIDR falls
  within the VCN CIDR (`cidrcontains`), no two subnet CIDRs are identical
  or overlap. This does not attempt exhaustive interval arithmetic for a
  partial overlap that contains neither CIDR's own network address — a
  case that cannot arise among these four same-size, non-nested `/24`
  allocations, but would need different math for an arbitrary future
  CIDR set. `cidrcontains`/`cidrhost` behavior confirmed empirically
  against the pinned OpenTofu 1.12.5 (`tofu console`), not assumed.
- **Tag ownership**: same OCI-managed-vs-Platform-managed split as
  `infrastructure/modules/foundation/state_backend.tf` — `lifecycle.ignore_changes`
  on exactly `Oracle-Tags.CreatedBy`/`Oracle-Tags.CreatedOn`, on both the
  VCN and every subnet, never the whole `defined_tags` attribute.

## Validation

```sh
cd infrastructure/modules/network
tofu fmt -check -recursive
tofu init -backend=false -input=false
tofu validate
tofu test
```

## Failure modes

- **Partial apply (VCN created, subnet creation fails)**: `oci_core_subnet`
  resources use `for_each`, so a failure creating one subnet leaves the
  others (and the VCN) in state correctly — re-running `tofu apply`
  retries only the missing subnet(s), no orphaned state.
- **CIDR self-check failure**: `tofu plan`/`apply` fails before any API
  call — the `check` block runs against the locals directly, so a bad
  hand-edit is caught before it ever reaches OCI.

## Upgrade expectations

Changing any subnet's CIDR or the VCN's CIDR forces replacement (OCI VCN/
subnet CIDRs are immutable) — destructive, and per REQ-NET-001/002 should
only ever happen via a superseding ADR, never a casual edit. Changing
`environment` updates the `Platform.Environment` tag value in place (no
replacement).

## Example

See `examples/minimal/main.tf`.

## Tests

`tests/network.tftest.hcl` (positive, `mock_provider`):

- VCN has the exact CIDR REQ-NET-001 mandates.
- All four subnets exist with the exact CIDRs REQ-NET-002 mandates.
- Edge subnet allows public IP; Management, Workload, and Data each
  independently assert `prohibit_public_ip_on_vnic == true` (not one
  representative check standing in for all three).
- The CIDR self-check `check` block assertions hold for the real locals
  (validated by `tofu validate`/`tofu test` succeeding at all — a broken
  `check` block fails the whole run).

`tests/network_negative.tftest.hcl`: this module's CIDRs are hardcoded
locals, not variables (see Input contract) — there is no variable surface
to feed a malformed/overlapping/out-of-range CIDR into, so classic
`expect_failures` negative tests don't apply the way they do for
`foundation`'s string/OCID variables. Malformed-CIDR protection is
enforced by `tofu validate`'s type system at parse time (a non-CIDR-shaped
string literal fails HCL evaluation immediately); overlap/containment/
duplication protection is enforced by `vcn.tf`'s `check` block instead
(see Security invariants). This file's negative tests instead cover the
one real variable-driven invariant this module has: rejecting an invalid
`environment` value.
