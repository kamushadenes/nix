# Task Integration Guide

Reference for ClickUp and Vanta integration in task agents.

## ClickUp Integration

### Config File: `.beads/clickup.yaml`

```yaml
linked_list:
  list_id: "<clickup_list_id>"
  list_name: "<name>"
  space_id: "<space_id>"
  space_name: "<name>"
linked_at: "<timestamp>"
last_sync: "<timestamp>"
```

### External Reference Format

`clickup-{task_id}` - e.g., `clickup-abc123xyz`

### Field Mapping: Beads ↔ ClickUp

| Beads Field | ClickUp Field | Notes |
|-------------|---------------|-------|
| `title` | `name` | Direct |
| `description` | `description` | Direct |
| `status` | `status` | Map values (see below) |
| `priority` | `priority` | Map values (see below) |
| `external_ref` | `id` | `clickup-{id}` format |
| `due` | `due_date` | Unix timestamp |
| `labels` | `tags` | Direct |

### Status Mapping

| Beads | ClickUp |
|-------|---------|
| `open` | "to do", "open", "backlog" |
| `in_progress` | "in progress", "doing" |
| `blocked` | "blocked", "on hold" |
| `closed` | "complete", "done", "closed" |

### Priority Mapping

| Beads | ClickUp |
|-------|---------|
| 0 (Critical) | 1 (Urgent) |
| 1 (High) | 2 (High) |
| 2 (Medium) | 3 (Normal) |
| 3 (Low) | 4 (Low) |
| 4 (Backlog) | null (No Priority) |

### Sync Operations

**Timestamp Comparison (CRITICAL):**
```bash
python3 ~/.config/nix/config/home/common/ai/resources/claude-code/scripts/helpers/compare-timestamps.py "<clickup_date_updated>" "<bead_updated_at>"
```
- Returns: `first` (ClickUp newer), `second` (bead newer), `equal`
- **NEWER wins** - never overwrite newer local state with older remote state

**Pull (ClickUp → Beads):**
1. Read config for `list_id`
2. `mcp__iniciador-clickup__clickup_search` with list filter
3. For each task:
   - Match by `external_ref=clickup-{task_id}`
   - If no match: create bead
   - If match: compare `date_updated` vs `updated_at`
     - ClickUp newer → update bead
     - Bead newer/equal → **SKIP** (preserve local state)
4. Update `last_sync` timestamp

**Push (Beads → ClickUp):**
1. `bd list --json` for local issues
2. For each with `external_ref`:
   - Compare timestamps
   - Bead newer → update ClickUp task
   - ClickUp newer → skip (handled in pull)
3. For each without: create ClickUp task, set `external_ref`

### MCP Tools

| Tool | Purpose |
|------|---------|
| `clickup_get_workspace_hierarchy` | List spaces/folders/lists |
| `clickup_search` | Find tasks by criteria |
| `clickup_get_task` | Get task details |
| `clickup_update_task` | Update task fields |
| `clickup_create_task` | Create new task |
| `clickup_get_task_comments` | Read comments |
| `clickup_create_task_comment` | Add comment |

---

## Vanta Integration

### Config File: `.beads/vanta.yaml`

```yaml
frameworks:
  - framework_id: "<id>"
    name: "SOC 2"
last_sync: "<timestamp>"
```

### External Reference Format

`vanta-control-{id}` or `vanta-test-{id}`

### Control → Bead Mapping

| Vanta Field | Beads Field |
|-------------|-------------|
| Control ID | `external_ref` |
| Control name | `title` |
| Description | `description` |
| Status (passing/failing) | `status` |
| Framework | `labels` |

### Sync Operations

**Pull Failing Controls:**
1. `mcp__iniciador-vanta__controls` - list all controls
2. Filter by `status != passing`
3. For each failing: create/update bead with `vanta-control-{id}`

**Track Remediation:**
1. Work on bead to fix the control
2. When fixed, close bead
3. Vanta will auto-detect passing status on next scan

### MCP Tools

| Tool | Purpose |
|------|---------|
| `frameworks` | List compliance frameworks |
| `list_framework_controls` | Controls for a framework |
| `controls` | Get control details |
| `tests` | List test results |
| `list_test_entities` | Entities for a test |
| `list_control_tests` | Tests for a control |
| `vulnerabilities` | Security vulnerabilities |
| `risks` | Risk items |

---

## Best Practices

1. **Always use external_ref** - Primary link between systems
2. **Sync before major work** - Pull latest state first
3. **Preserve timestamps** - Track `last_sync` for incremental sync
4. **Handle conflicts** - Prefer newer timestamp wins
5. **Log sync operations** - Audit trail for debugging
