# Runbooks

Runbooks land with the same PRs that introduce the operated capability.
M4 adds the first concrete bootstrap runbook for OpenBao TLS:

| Runbook | Lands with |
| --- | --- |
| `m4-bootstrap-openbao.md` | I11/M4 bootstrap TLS Secret path |
| `m4-bootstrap-dex.md` | I11/M4 Dex GitHub OAuth bootstrap Secret path |
| `node-replacement.md` | I04/I24, after Talos compute exists |
| `certificate-rotation.md` | I11 EPIC-SEC-03 |
| `secret-rotation.md` | I11 EPIC-SEC-01/02 |
| `backup-restore-drill.md` | I19 EPIC-DR-03 |
| `cluster-rebuild-from-git.md` | I19 EPIC-DR-03, proves the reproducibility principle in `docs/00-overview/vision.md` |

A runbook is added in the same PR as the capability it operates, per the
global Definition of Done (`docs/specs/README.md`) — never retrofitted
later.
