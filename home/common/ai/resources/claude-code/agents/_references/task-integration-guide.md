# Task Integration Guide

Reference for GitHub, ClickUp, and Vanta integration with task-master.

## ClickUp Integration

### Config File: `.taskmaster/clickup.yaml`

```yaml
workspace: <workspace_name>
list_id: "<clickup_list_id>"
list_name: "<name>"
space_id: "<space_id>"
space_name: "<name>"
linked_at: "<timestamp>"
last_sync: "<timestamp>"
```

### Linking Strategy

Tasks are linked by matching titles. When syncing:
- ClickUp task title matches task-master task title
- Include `[ClickUp:{task_id}]` prefix for explicit linking

### Field Mapping: Task-Master ↔ ClickUp

| Task-Master | ClickUp | Notes |
|-------------|---------|-------|
| title | name | Direct |
| description | description | Direct |
| status | status | Map values (see below) |
| priority | priority | Map values (see below) |

### Status Mapping

| Task-Master | ClickUp |
|-------------|---------|
| backlog | "to do", "open", "backlog" |
| in-progress | "in progress", "doing" |
| blocked | "blocked", "on hold" |
| done | "complete", "done", "closed" |

### Priority Mapping

| Task-Master | ClickUp |
|-------------|---------|
| high | 1 (Urgent) or 2 (High) |
| medium | 3 (Normal) |
| low | 4 (Low) |

### Sync Operations

**Pull (ClickUp → Task-Master):**
1. Read config for `list_id`
2. `mcp__iniciador-clickup__clickup_search` with list filter
3. For each task: create/update task-master task

**Push (Task-Master → ClickUp):**
1. `mcp__task-master-ai__get_tasks` for local tasks
2. For each: create/update ClickUp task

### MCP Tools

| Tool | Purpose |
|------|---------|
| `clickup_get_workspace_hierarchy` | List spaces/folders/lists |
| `clickup_search` | Find tasks by criteria |
| `clickup_get_task` | Get task details |
| `clickup_update_task` | Update task fields |
| `clickup_create_task` | Create new task |

---

## Vanta Integration

### Config File: `.taskmaster/vanta.yaml`

```yaml
frameworks:
  - framework_id: "<id>"
    name: "SOC 2"
iac_repos:  # Optional
  - url: "<git_url>"
    type: terraform|terragrunt
linked_at: "<timestamp>"
last_sync: "<timestamp>"
```

### Linking Strategy

Controls are linked by including `[Vanta:{control_id}]` in task title.

### Control → Task Mapping

| Vanta Field | Task-Master Field |
|-------------|-------------------|
| Control ID | Title prefix `[Vanta:{id}]` |
| Control name | Title |
| Description | Description |
| Status | status (passing → done) |
| Severity | priority |

### Priority Mapping

| Vanta Severity | Task-Master Priority |
|----------------|---------------------|
| Critical | high |
| High | high |
| Medium | medium |
| Low | low |

### Sync Operations

**Pull Failing Controls:**
1. `mcp__iniciador-vanta__list_framework_controls` for each framework
2. Filter for `status != passing`
3. For each failing: create/update task-master task with `[Vanta:{id}]` prefix

**Track Remediation:**
1. Work on task to fix the control
2. When fixed, mark task as done
3. Vanta will auto-detect passing status on next scan

### MCP Tools

| Tool | Purpose |
|------|---------|
| `frameworks` | List compliance frameworks |
| `list_framework_controls` | Controls for a framework |
| `controls` | Get control details |
| `tests` | List test results |
| `list_control_tests` | Tests for a control |
| `vulnerabilities` | Security vulnerabilities |
| `risks` | Risk items |

---

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

1. **Use title prefixes** - `[GH:#N]`, `[ClickUp:{id}]`, or `[Vanta:{id}]` for explicit linking
2. **Sync before major work** - Pull latest state first
3. **Preserve timestamps** - Track `last_sync` for incremental sync
4. **Handle conflicts** - Prefer newer timestamp wins
5. **Config in .taskmaster/** - Keep sync configs with task-master
