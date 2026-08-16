# Runbooks

Empty until the components they operate exist. First runbooks land with I19
(Backup & Disaster Recovery) and I24 (Operations & Day-2):

| Runbook | Lands with |
| --- | --- |
| `node-replacement.md` | I04/I24, after Talos compute exists |
| `certificate-rotation.md` | I11 EPIC-SEC-03 |
| `secret-rotation.md` | I11 EPIC-SEC-01/02 |
| `backup-restore-drill.md` | I19 EPIC-DR-03 |
| `cluster-rebuild-from-git.md` | I19 EPIC-DR-03, proves the reproducibility principle in `docs/00-overview/vision.md` |

A runbook is added in the same PR as the capability it operates, per the
global Definition of Done (`docs/specs/README.md`) — never retrofitted
later.
