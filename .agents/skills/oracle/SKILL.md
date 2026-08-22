---
name: oracle
description: Run long AI queries with Oracle CLI. Use for code reviews, summarization, or analysis that takes time. Always run in tmux.
---

# Oracle CLI

Run long-running AI queries. **Always run in tmux** so sessions persist.

## Usage

```bash
# Run query (in tmux!)
oracle -p "Summarize the risk register" \
  --slug risk-register-summary \
  --file docs/risk-register.md docs/risk-matrix.md

# Code review
oracle -p "Review the TS data layer" \
  --slug review-ts-data-layer \
  --file "src/**/*.ts" \
  --file "!src/**/*.test.ts"

# Audit
oracle -p "Audit data layer" \
  --slug audit-data-layer \
  --file "src/**/*.ts" \
  --file README.md
```

## Slug Naming

Choose descriptive slugs based on:
- The task being performed
- The project context
- Make it meaningful for later reference

## Session Management

```bash
# Check status
oracle status

# Prune old runs (1 week)
oracle status --clear --hours 168

# Replay a session
oracle status              # List runs, get ID
oracle session <id>        # Replay locally
```

## Tips

- Run in tmux: `tmux new -s oracle-run`
- Reattach later: `tmux attach -t oracle-run`
- Kill when done
