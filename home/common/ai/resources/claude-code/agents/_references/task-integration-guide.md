# Task Integration Guide

Reference for GitHub integration with task-master.

## GitHub Integration

### Config File: `.taskmaster/github.yaml`

```yaml
owner: "<owner>"
repo: "<repo>"
labels: []  # Optional: filter by labels
linked_at: "<timestamp>"
last_sync: "<timestamp>"
```

### Linking Strategy

Issues are linked by including `[GH:#<number>]` in task title.

### Issue -> Task Mapping

| GitHub Field | Task-Master Field |
|--------------|-------------------|
| Issue number | Title prefix `[GH:#123]` |
| Issue title | Title |
| Issue body | Description |
| State | status |
| Labels | priority |

### Status Mapping

| Task-Master | GitHub |
|-------------|--------|
| backlog | open |
| in-progress | open |
| blocked | open (labeled "blocked") |
| done | closed |

### Priority Mapping

| Task-Master | GitHub Labels |
|-------------|---------------|
| high | priority:high, urgent, critical |
| medium | priority:medium (or no label) |
| low | priority:low |

### Sync Operations

**Pull (GitHub -> Task-Master):**
1. `mcp__github__list_issues` with state: OPEN
2. For each issue: create/update task-master task with `[GH:#N]` prefix

**Push (Task-Master -> GitHub):**
1. `mcp__task-master-ai__get_tasks` for local tasks
2. For tasks with `[GH:#N]`: check issue status, comment if needed

### Worktree Workflow

For issue resolution with code changes:
1. `wt switch -c feat/<issue>-<slug>` - Create worktree
2. Make changes, run tests
3. Commit and push branch
4. `gh pr create` linking to issue
5. Update task-master task with PR link

### MCP Tools

| Tool | Purpose |
|------|---------|
| `list_issues` | List repository issues |
| `search_issues` | Search issues by criteria |
| `add_issue_comment` | Comment on issues |
| `create_pull_request` | Create PRs |

---

## Best Practices

1. **Use title prefixes** - `[GH:#N]` for explicit linking
2. **Sync before major work** - Pull latest state first
3. **Preserve timestamps** - Track `last_sync` for incremental sync
4. **Handle conflicts** - Prefer newer timestamp wins
5. **Config in .taskmaster/** - Keep sync configs with task-master
