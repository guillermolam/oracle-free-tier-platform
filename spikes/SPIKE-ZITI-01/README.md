# SPIKE-ZITI-01 — OpenZiti mesh + self-hosted zrok across peers

Status: In progress (issue
[#64](https://github.com/guillermolam/oracle-free-tier-platform/issues/64))

Supersedes SPIKE-EGRESS-01: the workerd / Cloudflare Workers egress-gateway
approach was rejected by the maintainer on security grounds (Workers/WASM
runtime posture). OpenZiti is the platform's single identity-based
zero-trust overlay (ADR-0003).

## Question

Can the platform's OpenZiti overlay be stood up following the official docs,
with every environment as a peer (Mac, OrbStack, OCI Always Free lab,
UpCloud), using self-hosted zrok for NAT-traversing share/access — removing
the need for NAT GW / Service GW objects entirely?

## Why it matters

- NAT GW (limit 0) and SGW (limit 0) block M1 egress; the OpenZiti mesh
  replaces them with identity-policy egress (no blanket 0.0.0.0/0 NAT).
- Multi-environment peer mesh (OrbStack + OCI + UpCloud) is exactly the
  platform's hybrid/multi-cloud future (I21/I22) — validated early.
- zrok (built on OpenZiti) gives NAT traversal + secure sharing with zero
  firewall changes — the "tunnels/peers/NAT traversal" requirement.

## Feasibility questions (Given/When/Then)

| # | Question | Risk |
| --- | --- | --- |
| MESH-LOCAL | Given the official quickstart compose (get.openziti.io) running in OrbStack, when an identity is created and a service bound/dialed, then a client reaches the service through the fabric with zero open ports | Medium |
| ZITI-TOOLS | Given the mesh up, when ziti-edge-tunnel / ziti-tunnel / ziti-host / zrok CLI are exercised, then each connects through the fabric as documented | Medium |
| ZROK-SELFHOSTED | Given a self-hosted zrok controller+frontend on the Ziti network, when `zrok share public/private` runs on one peer, then another peer `zrok access`es it through NAT (no firewall changes) | High |
| NAT-TRAVERSAL | Given peers behind NAT (home network, OCI, UpCloud), when they enroll routers, then they link into the mesh without public IPs or port forwarding | High |

## Lab topology (local-first)

```text
OrbStack (Docker on the Mac)
  openziti/quickstart compose:
    ziti-controller (1280 edge, 6262 ctrl)
    ziti-edge-router (3022, roles=public)
    ziti-console / ZAC (8443)
Mac: ziti CLI v2.0.2 (installed) + zrok CLI (brew)
  -> enroll identities, create services/policies, test fabric
Later peers: OCI lab (2x A1, capacity-pending, provision.sh) and UpCloud
  (infrastructure/live/upcloud) enroll edge routers; zrok self-hosted on top.
```

## Evidence chain (append as produced)

- [ ] Quickstart compose healthy in OrbStack (controller/router/console).
- [ ] `ziti edge login` + `ziti edge list identities/services/policies`.
- [ ] Service reachable end-to-end through the fabric (echo proof).
- [ ] zrok controller + frontend self-hosted; share/access round-trip.
- [ ] Identity join/eviction: policy revocation kills an active session.

## Verdict

_Pending — filled when the spike closes._
