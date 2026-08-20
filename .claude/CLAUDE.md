# .claude/ — tooling, not source of truth

The canonical AI-operating doc for this repo is the root [AGENTS.md](../AGENTS.md)
(symlinked as `CLAUDE.md`) — its source-of-truth order, ownership boundaries, and
routing model apply in full. Nothing here restates or supersedes it.

This directory supplies tooling only:

- `agents/` — subagents for IaC planning, state/secrets auditing, docs
  governance, and PR readiness. See each agent's frontmatter for scope.
- `skills/` — procedural knowledge (how to run Terragrunt, research OCI
  provider behavior, check the secrets boundary, etc.) and operator
  commands (`/validate`, `/pr-ready`, ...). Each skill links to canonical
  docs rather than duplicating them.
- `hooks/` — deterministic defense-in-depth around destructive commands
  and a session-end reflection prompt. The hard security boundary is
  `permissions.deny` in `settings.json`, not the hooks.
- `settings.json` — least-privilege Bash permissions and sandbox config.
  This file is the actual enforcement layer for this directory.
