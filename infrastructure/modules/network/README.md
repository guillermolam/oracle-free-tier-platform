# `network` module

## Purpose

Implements `SPEC-NET-001` (REQ-NET-001..005, the platform VCN and its
four trust-zone subnets), `SPEC-NET-002` (REQ-NET-006..010, gateways:
Internet, NAT, Service, and an inert DRG), `SPEC-NET-003`
(REQ-NET-011..015, one route table per trust zone), and — pulled forward
from what was originally PR C3's scope — `SPEC-NET-004`'s **coarse
baseline only** (REQ-NET-016/018: one default-deny Security List per
zone). As decided by `ADR-0006` and `ADR-0008`. This is the second module
in the state DAG — `SPEC-NET-004`'s remaining scope (REQ-NET-017/019/020:
the five purpose-built NSGs, `control` NSG's port-6443 restriction) and
`SPEC-NET-006` (DNS/DHCP) still attach to what this module creates, and
I04 (compute) attaches to its subnets/route tables. `ADR-0007` already
decided `10-network` is one state unit covering all of `SPEC-NET-001`
through `SPEC-NET-006` — this module is built incrementally across PRs
against that same eventual state unit (PR C: `vcn.tf` + `subnets.tf`;
PR C2, this one: `gateways.tf` + `routing.tf` + `security_lists.tf`; a
later PR adds `nsgs.tf`/`dns.tf`), per `../README.md`'s own documented
internal-file-organization note. Not a further-split target: OCI network
topology within one VCN is provisioned and changed as a unit in
practice.

**Why the Security List baseline moved into PR C2**: applying IGW routing
to Edge (`gateways.tf`/`routing.tf`, this same PR) while every subnet
still inherited OCI's permissive default Security List (TCP/22 + ICMP
from `0.0.0.0/0`) would have been a real, avoidable transitional
exposure, not a hypothetical one — Edge specifically becomes
internet-routable in this PR. `security_lists.tf` closes that gap with
the minimum necessary baseline (REQ-NET-016/018) without pulling forward
NSGs, OpenZiti-specific rules, Kubernetes control-plane authorization
(REQ-NET-019), or any other component-level authorization — those remain
PR C3 exactly as originally scoped.

## Input contract

| Variable | Type | Required | Validation |
| --- | --- | --- | --- |
| `compartment_ocid` | string | yes | must match `^ocid1\.compartment\.` |
| `environment` | string | yes | one of `lab`, `staging`, `prod` |
| `platform_name` | string | no (default `"oracle-free-tier-platform"`) | — |
| `use_managed_nat` | bool | no (default `false`) | — |
| `use_managed_service_gateway` | bool | no (default `false`) | — |
| `nat_egress_target_ocid` | string | no (default `null`) | must be `null` or match `^ocid1\.privateip\.`; mutually exclusive with `use_managed_nat` (checked) |

`use_managed_nat`/`use_managed_service_gateway` default to `false` because
this Always Free account has a hard limit of 0 NAT gateways and 0 service
gateways — the managed resources cannot be the real egress path. The
software-NAT instance (I04/compute `micro-nat`) is the default egress
target, resolved at runtime by freeform tag (`data.tf`), not by a
cross-unit Terragrunt dependency — see "Software-NAT discovery" below.
`nat_egress_target_ocid` is the explicit escape hatch: set it to pin the
egress target and bypass tag discovery.

No CIDR variables. REQ-NET-001/REQ-NET-002 mandate exact values, and
ADR-0006 is explicit they're fixed absent a superseding ADR — see
`vcn.tf`'s locals and `variables.tf`'s comment for why these are
hardcoded constants, not tunables.

## Output contract

| Output | Consumed by |
| --- | --- |
| `vcn_id` | `SPEC-NET-004` (NSGs/Security Lists) |
| `vcn_cidr` | downstream modules needing the VCN's own range (e.g. future DRG peering, I21) |
| `subnet_ids` | map keyed by zone (`edge`/`management`/`workload`/`data`) — `SPEC-NET-004`/I04 attach resources to specific subnets by zone |
| `subnet_cidrs` | map keyed by zone — downstream Security List/NSG rules referencing zone ranges |
| `igw_id` / `nat_id` / `sgw_id` / `drg_id` | consumed internally by `routing.tf`; `drg_id` also for I21 once hybrid connectivity begins |
| `drg_route_table_id` | I21 — the table it populates once hybrid routing activates |
| `route_table_ids` | map keyed by zone — I04 (compute subnet attachment) |
| `security_list_ids` | map keyed by zone — PR C3's NSGs layer on top of these; I04 attaches compute to the same zone's list |

## Resource ownership

`oci_core_vcn` (1), `oci_core_subnet` (4, one per trust zone, via
`for_each`), `oci_core_internet_gateway` (1), `oci_core_nat_gateway` (0–1,
count-gated by `use_managed_nat`), `oci_core_service_gateway` (0–1,
count-gated by `use_managed_service_gateway`), `oci_core_drg` (1),
`oci_core_drg_route_table` (1, empty — the inert mechanism),
`oci_core_drg_attachment` (1), `oci_core_route_table` (4, one per trust
zone, via `for_each`), `oci_core_security_list` (4, one per trust zone,
via `for_each` — baseline only, REQ-NET-016/018),
`data.oci_core_services` (1, read-only — resolves the region's Services
Network CIDR label), `data.oci_core_instances` (1, read-only — software-NAT
tag discovery), `data.oci_core_private_ips` (1, read-only — resolves the
discovered instance's private IP for the egress route).

**Not owned here**: NSGs (`SPEC-NET-004`'s remaining scope,
REQ-NET-017/019/020), DNS/DHCP options (`SPEC-NET-006`), compute
attachment (I04), any DRG route rule/distribution (I21 — this module
creates the DRG attached-but-empty, never populates it). Subnets no
longer use OCI's default route table or default Security List — each has
its own zone-specific pair now (`routing.tf`, `security_lists.tf`); the
OCI defaults become intentionally unused, not deleted.

## Software-NAT discovery

The Always Free account cannot hold a managed NAT gateway (quota: 0), so
egress for Management/Workload/Data zones must target the `micro-nat`
compute instance instead. To keep `10-network` and `30-compute` as
independent Terragrunt state units — no circular dependency — the network
module discovers the instance at plan time by its freeform tag
(`role = "software-nat"`), never by importing `30-compute`'s outputs:

- `data.oci_core_instances.software_nat` lists instances in the
  compartment filtered by `freeform_tags."role" = "software-nat"`
  (defensive `try()`/`one()` so a tag never missing is not a hard error at
  plan time — an empty result is simply `null`).
- `data.oci_core_private_ips.software_nat` resolves that instance's VNIC
  private IP by `ip_address` alone (no `subnet_id` filter — the private-IP
  lookup must not read the route table it feeds, which would re-introduce
  a cycle through `oci_core_subnet`).
- `local.nat_egress_target`/`local.nat_egress_target_ocid` resolve to the
  explicit `nat_egress_target_ocid` when set, otherwise to the managed NAT
  when `use_managed_nat` is set, otherwise to the discovered instance.

Resolution order (first match wins):

| Source | Condition |
| --- | --- |
| `nat_egress_target_ocid` | non-null (explicit escape hatch) |
| `oci_core_nat_gateway.this[0]` | `use_managed_nat` |
| discovered `micro-nat` instance | tag match present |
| none | egress route is `null` (no `0.0.0.0/0` rule) |

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
  on exactly `Oracle-Tags.CreatedBy`/`Oracle-Tags.CreatedOn`, on every
  resource this module creates, never the whole `defined_tags` attribute.
- **REQ-NET-010/013 (binding control)**: no route table other than Edge
  may ever reference the Internet Gateway. Enforced structurally, not
  just by convention — every route table's rule set is built from one
  shared `local.route_tables` map (`routing.tf`), so there is exactly one
  place an accidental Internet Gateway rule could be added to a
  non-Edge zone, and `tests/routing.tftest.hcl`'s
  `management_workload_data_never_reference_the_internet_gateway` asserts
  the *absence* directly — not merely that a NAT rule is also present,
  which alone wouldn't catch a table carrying both.
- **REQ-NET-009/ADR-0008 (DRG inertness)**: the DRG attachment references
  this module's own `oci_core_drg_route_table.inert`, which carries zero
  static routes (no `oci_core_drg_route_table_route_rule` resource exists
  in this module) and no `import_drg_route_distribution_id` (unset —
  no propagation configured). Both together are what "present but inert"
  means. `mock_provider` cannot prove the second half of this (see
  `tests/gateways.tftest.hcl`'s `drg_route_table_is_inert` comment) —
  verified against the real provider in the PR C2 deployment report
  instead.
- **REQ-NET-008/014 (Service Gateway target)**: the Services Network CIDR
  label is resolved via `data.oci_core_services` and matched by name
  pattern (`"All .* Services In Oracle Services Network"`), never
  hardcoded — keeps this module region-neutral and fails loudly (a
  `null` attribute-access error) if OCI's API shape ever changes rather
  than silently misconfiguring the Service Gateway.
- **REQ-NET-011**: every subnet's `route_table_id` now points at its own
  zone's explicit route table (`subnets.tf`), never the VCN default —
  audited against the live tenancy before this change (all four subnets
  previously fell back to the empty default route table).
- **REQ-NET-016/018 (Security List baseline, pulled forward from
  `SPEC-NET-004`)**: every subnet's `security_list_ids` now points at its
  own zone's baseline Security List (`security_lists.tf`), never the VCN
  default — same audit-before-change discipline as REQ-NET-011. Each
  list has **zero ingress rules** (default-deny; `tests/security_lists.tftest.hcl`
  asserts this independently per zone, not just once) and egress scoped
  to exactly the two destinations this module's own routing needs
  (`0.0.0.0/0` matching the NAT/IGW route, the Services CIDR label
  matching the Service Gateway route) — not a blanket copy of OCI's
  permissive default. This exists specifically because Edge becomes
  IGW-routable in this same PR; shipping that without a Security List
  baseline would have left a real transitional exposure, not a
  hypothetical one. **Routable is still not authorized**: this baseline
  proves nothing is exposed today, not that anything is cleared to be —
  NSG-level component authorization (REQ-NET-017/019/020) remains
  PR C3.

## Requirement traceability

| REQ | Spec | ADR | ARCH-* | Threat-model flow | OCI resource | OpenTofu address | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| REQ-NET-001 | SPEC-NET-001 | ADR-0006 | ARCH-NET-VCN | — | VCN | `oci_core_vcn.this` | `vcn_has_exact_cidr` |
| REQ-NET-002 | SPEC-NET-001 | ADR-0006 | ARCH-ZONE-* | — | Subnet ×4 | `oci_core_subnet.this` | `four_subnets_with_exact_cidrs` |
| REQ-NET-003 | SPEC-NET-001 | ADR-0006 | ARCH-ZONE-MGMT/WORKLOAD/DATA | — | Subnet | `prohibit_public_ip_on_vnic` | `{mgmt,workload,data}_subnet_prohibits_public_ip` |
| REQ-NET-004 | SPEC-NET-001 | ADR-0006 | ARCH-ZONE-EDGE | ARCH-FLOW-INGRESS (RED) | Subnet | `prohibit_public_ip_on_vnic` | `edge_subnet_allows_public_ip` |
| REQ-NET-005 | SPEC-NET-001 | — | — | — | (output contract) | `outputs.tf` | n/a — structural |
| REQ-NET-006 | SPEC-NET-002 | — | ARCH-FLOW-INGRESS (RED) | ARCH-FLOW-INGRESS | Internet Gateway | `oci_core_internet_gateway.this` | `internet_gateway_enabled` |
| REQ-NET-007 | SPEC-NET-002 | — | ARCH-FLOW-EGRESS (GREEN) | ARCH-FLOW-EGRESS | NAT Gateway | `oci_core_nat_gateway.this` | `nat_gateway_exists` |
| REQ-NET-008 | SPEC-NET-002 | — | ARCH-FLOW-SERVICE (BLUE) | ARCH-FLOW-SERVICE | Service Gateway | `oci_core_service_gateway.this` | `service_gateway_targets_all_services` |
| REQ-NET-009 | SPEC-NET-002 | ADR-0008 | ARCH-FLOW-HYBRID (ORANGE) | ARCH-FLOW-HYBRID | DRG + attachment + empty DRG RT | `oci_core_drg.this` / `.inert` / `.vcn` | `drg_exists_and_is_attached`, `drg_route_table_is_inert` |
| REQ-NET-010 | SPEC-NET-002 | — | ARCH-FLOW-INGRESS | ARCH-FLOW-INGRESS | (constraint on all gateways) | n/a — no other gateway carries a `0.0.0.0/0` inbound rule by construction | covered by route-table tests, not a gateway-object test |
| REQ-NET-011 | SPEC-NET-003 | ADR-0006 | ARCH-ZONE-* | — | Route Table ×4 | `oci_core_route_table.this` | `four_route_tables_one_per_zone`, `every_subnet_uses_its_own_zone_route_table_not_the_default` |
| REQ-NET-012 | SPEC-NET-003 | — | ARCH-FLOW-INGRESS (RED) | ARCH-FLOW-INGRESS | Route rule (Edge → IGW) | `oci_core_route_table.this["edge"]` | `edge_route_table_routes_internet_to_igw` |
| REQ-NET-013 | SPEC-NET-003 | — | ARCH-FLOW-EGRESS (GREEN) | ARCH-FLOW-EGRESS | Route rule (Mgmt/Workload/Data → NAT, never IGW) | `oci_core_route_table.this[zone]` | `management_workload_data_never_reference_the_internet_gateway`, `management_workload_data_route_internet_to_nat_only` |
| REQ-NET-014 | SPEC-NET-003 | — | ARCH-FLOW-SERVICE (BLUE) | ARCH-FLOW-SERVICE | Route rule (all zones → SGW) | `oci_core_route_table.this[*]` | `all_four_zones_route_services_cidr_to_service_gateway` |
| REQ-NET-015 | SPEC-NET-003 | ADR-0008 | ARCH-FLOW-HYBRID (ORANGE) | ARCH-FLOW-HYBRID | (reserved slot, unpopulated) | n/a — no resource by design | `no_route_table_references_the_drg` |
| REQ-NET-016 | SPEC-NET-004 (baseline only) | — | ARCH-ZONE-* | — | Security List ×4 | `oci_core_security_list.this` | `four_security_lists_one_per_zone`, `every_subnet_uses_its_own_zone_security_list_not_the_default` |
| REQ-NET-018 | SPEC-NET-004 (baseline only) | — | ARCH-FLOW-INGRESS/EGRESS/SERVICE | ARCH-FLOW-INGRESS | Security List rules (empty ingress; egress = 2 rules matching routing) | `oci_core_security_list.this[zone]` | `{edge,management,workload,data}_has_no_(unauthorized\|internet)_ingress`, `no_zone_permits_ssh_from_the_internet`, `no_zone_permits_unrestricted_ingress_of_any_kind`, `egress_scoped_to_exactly_what_routing_needs` |

No orphan infrastructure: every resource and route rule in `gateways.tf`/
`routing.tf`/`security_lists.tf` traces to one of the rows above. Nothing
was added that isn't required by REQ-NET-006 through REQ-NET-018 (with
REQ-NET-017/019/020 explicitly out of scope — see Purpose).

## Route matrix

| Source zone | Destination class | Next hop | Destination prefix/service | Flow class | REQ | Implemented now? |
| --- | --- | --- | --- | --- | --- | --- |
| Edge | Internet | Internet Gateway | `0.0.0.0/0` | RED (INGRESS)/GREEN (EGRESS) | REQ-NET-012 | Yes |
| Edge | OCI services | Service Gateway | Services Network CIDR label | BLUE (SERVICE) | REQ-NET-014 | Yes |
| Management | Internet (egress only) | software-NAT instance (or managed NAT if enabled) | `0.0.0.0/0` | GREEN (EGRESS) | REQ-NET-013 | Yes |
| Management | OCI services | Service Gateway | Services Network CIDR label | BLUE (SERVICE) | REQ-NET-014 | Yes |
| Management | future on-prem/other-cloud | DRG | (reserved, unpopulated) | ORANGE (HYBRID) | REQ-NET-015 | No — I21 |
| Workload | Internet (egress only) | software-NAT instance (or managed NAT if enabled) | `0.0.0.0/0` | GREEN (EGRESS) | REQ-NET-013 | Yes |
| Workload | OCI services | Service Gateway | Services Network CIDR label | BLUE (SERVICE) | REQ-NET-014 | Yes |
| Data | Internet (egress only) | software-NAT instance (or managed NAT if enabled) | `0.0.0.0/0` | GREEN (EGRESS) | REQ-NET-013 | Yes |
| Data | OCI services (incl. backup) | Service Gateway | Services Network CIDR label | BLUE (SERVICE)/BLUE (BACKUP) | REQ-NET-014 | Yes |

The Management/Workload/Data egress target resolves via "Software-NAT
discovery" below: explicit `nat_egress_target_ocid` → managed NAT →
tag-discovered `micro-nat` → no rule. The interim state (no target yet)
is a deliberate `null` — the rule is absent, not broken.

No unexplained `0.0.0.0/0` — every occurrence above is either Edge→IGW
(REQ-NET-012, the only place it's allowed) or Management/Workload/Data→NAT
(REQ-NET-013, explicitly never IGW; the NAT is the software-NAT instance
by default, the managed gateway only when enabled).

## Security List baseline matrix

| Zone | Direction | Source/Destination | Protocol | Purpose | REQ |
| --- | --- | --- | --- | --- | --- |
| Edge | Ingress | — (none) | — | Default-deny; routable via IGW does not mean authorized — NSG-level authorization is PR C3 | REQ-NET-018 |
| Edge | Egress | `0.0.0.0/0` | all | Matches Edge's own IGW route (REQ-NET-012) — a route with no matching egress rule is unusable | REQ-NET-016 |
| Edge | Egress | Services CIDR label | all | Matches Edge's Service Gateway route (REQ-NET-014) | REQ-NET-016 |
| Management | Ingress | — (none) | — | Default-deny — NAT is egress-only by OCI design regardless, but the SL is the platform-level control, not an assumption about NAT behavior | REQ-NET-018 |
| Management | Egress | `0.0.0.0/0` | all | Matches Management's NAT route (REQ-NET-013) | REQ-NET-016 |
| Management | Egress | Services CIDR label | all | Matches Management's Service Gateway route (REQ-NET-014) | REQ-NET-016 |
| Workload | Ingress | — (none) | — | Default-deny, same reasoning as Management | REQ-NET-018 |
| Workload | Egress | `0.0.0.0/0` | all | Matches Workload's NAT route (REQ-NET-013) | REQ-NET-016 |
| Workload | Egress | Services CIDR label | all | Matches Workload's Service Gateway route (REQ-NET-014) | REQ-NET-016 |
| Data | Ingress | — (none) | — | Default-deny, same reasoning as Management | REQ-NET-018 |
| Data | Egress | `0.0.0.0/0` | all | Matches Data's NAT route (REQ-NET-013) | REQ-NET-016 |
| Data | Egress | Services CIDR label | all | Matches Data's Service Gateway route (REQ-NET-014) | REQ-NET-016 |

No ingress rule exists anywhere in this table — every zone's Security
List is empty on ingress, independently asserted per zone in
`tests/security_lists.tftest.hcl`, not inferred from one representative
check. Egress is deliberately **not** a blanket copy of OCI's default
(`all protocols → 0.0.0.0/0` with no Services-CIDR distinction) — every
row above traces to a route this module's own `routing.tf` already
creates; there is no egress destination in this table that routing
doesn't also send traffic to.

**Software-NAT is route-only today — forwarding is not yet authorized.**
The `micro-nat` instance (I04/compute) lives on the Edge subnet, so the
Management/Workload/Data → `0.0.0.0/0` route's traffic arrives at its
VNIC as *ingress to Edge*. With this baseline's zero Edge ingress rules,
that traffic is deliberately dropped — the software-NAT path cannot
forward until I04 attaches micro-nat's own authorization (an NSG or
Security List ingress rule permitting the Management/Workload/Data CIDRs
to reach it) *and* sets `skip_source_dest_check` on its VNIC, both of
which are I04/compute concerns outside this module. Until then, "routable
but not authorized" holds *for the forwarded path itself*, not just for
unrelated inbound traffic — this is the intended interim state, not a
gap: the route exists so the target is pinned correctly, and the drop is
the baseline's default-deny doing its job.

## Traffic-flow reconciliation (post–PR C2)

Using `docs/01-architecture/traceability.md`'s RED/GREEN/BLUE/PURPLE/
ORANGE taxonomy (`ARCH-FLOW-*` → color mapping) — no new taxonomy
invented here:

- **Physically exist (routable) after PR C2**: RED (`ARCH-FLOW-INGRESS`),
  GREEN (`ARCH-FLOW-EGRESS`), BLUE (`ARCH-FLOW-SERVICE`/`-BACKUP`).
- **Routable but not yet authorized**: the same three — routes exist, and
  as of this PR every zone now has its own default-deny Security List
  baseline (REQ-NET-016/018, `security_lists.tf`), not the shared OCI
  default. "Routable" still isn't "permitted": the baseline proves no
  zone is exposed *today* (zero ingress rules everywhere), it does not
  grant any component authorization — NSG-level rules (REQ-NET-017/019/020,
  PR C3) are what turn "routable and default-denied" into "routable and
  specifically permitted for a real component." This is a meaningfully
  different, stronger position than PR C2's first draft, which left every
  subnet on the shared default Security List (SSH/ICMP from `0.0.0.0/0`)
  while making Edge IGW-routable in the same PR — a real, avoidable
  transitional exposure, closed before this PR's apply gate rather than
  carried into PR C3.
- **Remain physically impossible**: PURPLE (`ARCH-FLOW-ADMIN`/`-CONTROL`)
  — no OpenZiti, no compute/Talos exists yet (I04/I08/M2); this module
  creates no path for either.
- **Intentionally deferred**: ORANGE (`ARCH-FLOW-HYBRID`) — DRG present,
  attached, and inert by construction (ADR-0008); zero routes reference it
  anywhere in this module.

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
- **Service Gateway target lookup fails** (`data.oci_core_services`
  returns no match for the `"All .* Services In Oracle Services Network"`
  pattern): `local.all_services_in_oracle_services_network` evaluates to
  `null`, and referencing `.id`/`.cidr_block` on it fails loudly with an
  "Attempt to get attribute from null value" error at plan time — never a
  silently misconfigured Service Gateway route. Not currently unit-testable
  (see `tests/gateways.tftest.hcl`'s mock limitations note); would need
  a real API response change to trigger.
- **Partial apply mid-gateway-creation**: each gateway is its own
  resource (no `for_each`/`count` linking them), so a failure creating,
  say, the NAT Gateway leaves the Internet Gateway and Service Gateway
  correctly in state — re-running `tofu apply` retries only what's
  missing.
- **Software-NAT discovery empty**: if the compartment contains no
  instance tagged `role = "software-nat"` and neither
  `nat_egress_target_ocid` nor `use_managed_nat` is set, the egress route
  resolves to `null` and Management/Workload/Data simply have no
  `0.0.0.0/0` rule — an explicit, documented interim state (see Route
  matrix), not a broken plan. The route appears automatically on the next
  `10-network` apply after `30-compute` provisions `micro-nat`.
- **Multiple software-NAT instances tagged**: `one()` fails loudly at plan
  time if discovery matches more than one instance — a
  miscustomization, surfaced rather than silently choosing one.

## Upgrade expectations

Changing any subnet's CIDR or the VCN's CIDR forces replacement (OCI VCN/
subnet CIDRs are immutable) — destructive, and per REQ-NET-001/002 should
only ever happen via a superseding ADR, never a casual edit. Changing
`environment` updates the `Platform.Environment` tag value in place (no
replacement). Changing a subnet's `route_table_id` (e.g. reassigning
which route table a zone uses) is an in-place update, not a replacement —
OCI subnets don't force-replace on route table changes; restoring the
prior route table ID is the rollback path, not `tofu destroy`.

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
variable-driven invariants this module has: rejecting an invalid
`environment` value, rejecting a non-private-IP OCID for
`nat_egress_target_ocid` (an IGW OCID would otherwise be copied verbatim
into all three private-zone routes, silently bypassing the Edge-only
gateway invariant), and rejecting the `use_managed_nat` + explicit-target
conflict via the mutual-exclusivity `check` block.

`tests/gateways.tftest.hcl` (positive): Internet Gateway enabled, NAT
Gateway attached, Service Gateway resolves the real Services CIDR label
(not hardcoded), DRG attached to the VCN specifically, DRG attachment
references this module's own empty DRG route table, no gateway carries
an `Oracle-Tags.*` key. Does **not** test that the DRG route table's
`import_drg_route_distribution_id` stays null — `mock_provider`
synthesizes a plausible fake value for every computed attribute
regardless of whether config leaves it unset (confirmed empirically,
same class of constraint as `foundation`'s `ignore_changes`-on-a-
config-set-attribute limitation) — verified against the real provider
in the PR C2 deployment report instead.

`tests/routing.tftest.hcl` (positive; doubles as the negative-shaped
security tests — see below): four route tables exist, every subnet uses
its own zone's table rather than the default, Edge routes `0.0.0.0/0` to
the Internet Gateway, all four zones route the Services CIDR label to
the Service Gateway, no route table references the DRG. The single most
important assertion —
`management_workload_data_never_reference_the_internet_gateway` — is
written as a positive assertion of an *absence*, which is what actually
proves REQ-NET-013's binding control; a presence-only check for the NAT
rule wouldn't catch a table that had both. A second run
(`management_workload_data_route_internet_to_discovered_software_nat`)
mocks the software-NAT discovery (`data.tf`) and asserts the
Management/Workload/Data tables target the discovered instance's private
IP. No separate
`routing_negative.tftest.hcl` exists: this module's route rules are
built entirely from hardcoded locals (`local.route_tables`), not
variables, so there's no user-input surface for `expect_failures`-style
malformed/overlapping-route negative tests the way `foundation`'s
string/OCID variables have — the same reasoning as `network_negative.tftest.hcl`
above, applied to routing.

`tests/security_lists.tftest.hcl` (positive; these ARE this module's
critical security invariants, same pattern as `routing.tftest.hcl`):
exactly four Security Lists exist; no zone permits TCP/22 from
`0.0.0.0/0` (checked as one combined assertion, not per-zone, since the
underlying invariant — zero ingress rules — is stronger and checked
per-zone separately below); Edge, Management, Workload, and Data each
**independently** assert zero ingress rules (not one representative
check standing in for all four, matching this module's established
per-zone-assertion discipline); a combined
`no_zone_permits_unrestricted_ingress_of_any_kind` assertion restates the
same fact as the strongest possible form of "no unrestricted ingress
exists anywhere"; egress is exactly 2 rules per zone, matching what
`routing.tf` actually routes (not a blanket `0.0.0.0/0` reproduction);
every subnet references its own zone's Security List, never the OCI
default. Does not attempt to unit-test *effective live reachability*
(whether a real internet client could actually reach a real resource) —
that's not a mock-provider-provable claim, and the real plan/OCI CLI
verification in the PR C2 deployment report is the authoritative check,
consistent with how this module already treats DRG inertness.
