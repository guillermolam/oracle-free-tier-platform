# Operations

Day-2 lifecycle management: upgrades, rotation, scaling, incident response,
policy evolution. Owned by I24 (Operations & Day-2) and populated as the
initiatives it depends on ship — an operations doc for a component that
doesn't exist yet would be speculative, not documentation.

## Planned contents

| Doc | Populated when |
| --- | --- |
| `upgrade-strategy.md` (Talos / Kubernetes / Cilium / Flux) | I24 EPIC-OPS-02, after I05/I07/I12 ship |
| `credential-rotation.md` | I24 EPIC-OPS-01, after I11 (Secrets & PKI) ships |
| `incident-response.md` | I24 EPIC-OPS-03 |
| `capacity-and-free-tier-envelope.md` | after I02/I04, tracking actual OCI Free Tier consumption against the budget in `docs/00-overview/vision.md` |

Runbooks (specific step-by-step procedures) live in
[`docs/06-runbooks/`](../06-runbooks/README.md); this directory holds the
strategy and policy documents runbooks execute against.
