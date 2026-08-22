---
name: taskwarrior
description: Track work items using Taskwarrior. Use when managing tasks, tracking PRs, or organizing work. Always use UUID instead of task ID.
---

# Taskwarrior

Track work items with Taskwarrior. **Always use UUID** - IDs shift when tasks complete.

## Basic Commands

```bash
# List tasks
task project:<project> list
task project:<project> status:pending list
task project:<project> +COMPLETED all

# Task operations (use UUID!)
task <uuid> info
task <uuid> done
task <uuid> annotate "Note here"
task <uuid> modify <attribute>:<value>
```

## Get UUIDs

```bash
# Export with UUIDs
task project:<project> export | jq -r ".[] | \"\\(.uuid) | \\(.description)\""

# Get UUID from ID
task <id> export | jq -r ".[0].uuid"
```

## PR Tracking Workflow

```bash
# Link PR to task
task <uuid> annotate "PR opened: https://github.com/org/repo/pull/123"
```

## Common Workflow

1. `task <uuid> annotate "STARTED: description"`
2. `task <uuid> annotate "DONE: completed X"`
3. `task <uuid> annotate "PR opened: <url>"`
4. `task <uuid> done` (after PR merged)
