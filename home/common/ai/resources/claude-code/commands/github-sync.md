---
allowed-tools: Task, MCPSearch, mcp__task-master-ai__*, mcp__github__*
description: Sync GitHub issues with task-master bidirectionally
---

## Context

- Task-master initialized: !`test -d .taskmaster && echo "yes" || echo "no"`
- GitHub config: !`cat .taskmaster/github.yaml 2>/dev/null || echo "Not linked"`
- Current repo: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "Not in repo"`

## Your Task

Use the **Task tool** with `subagent_type='task-agent'` to run the sync.

### If task-master is NOT initialized (.taskmaster directory missing):

Tell the user to initialize task-master first:
```bash
# Use the initialize_project MCP tool or run:
npx task-master-ai init
```

### If GitHub is NOT linked (.taskmaster/github.yaml missing):

1. Detect current repo from git remote or ask user
2. Create `.taskmaster/github.yaml`:

```yaml
owner: "<owner>"
repo: "<repo>"
labels: []  # Optional: filter by labels
linked_at: "<ISO 8601 timestamp>"
last_sync: null
```

### If GitHub IS linked (.taskmaster/github.yaml exists):

Run bidirectional sync:

**PULL (GitHub -> task-master):**
1. Read config for `owner` and `repo`
2. Use `mcp__github__list_issues` with state: OPEN
3. For each GitHub issue:
   - Check if task-master task exists with `[GH:#<number>]` in title
   - If no match: use `mcp__task-master-ai__add_task` to create
   - If match: compare updated_at, update if GitHub is newer

**PUSH (task-master -> GitHub):**
1. Use `mcp__task-master-ai__get_tasks` to list local tasks
2. For tasks with `[GH:#<number>]` prefix:
   - Check GitHub issue status
   - If task done but issue open: add comment suggesting close
   - If task blocked: add comment with blocker info

**Status Mapping:**

| Task-Master | GitHub |
|-------------|--------|
| backlog | open |
| in-progress | open |
| done | closed |
| blocked | open (labeled "blocked") |

**Priority Mapping:**

| Task-Master | GitHub Labels |
|-------------|---------------|
| high | priority:high, urgent, critical |
| medium | priority:medium (or no priority label) |
| low | priority:low |

4. Update `last_sync` in config

Report sync results when complete.
