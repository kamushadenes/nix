---
allowed-tools: Task, MCPSearch, mcp__task-master-ai__*, mcp__iniciador-vanta__*
description: Sync Vanta compliance controls with task-master for remediation tracking
---

## Context

- Task-master initialized: !`test -d .taskmaster && echo "yes" || echo "no"`
- Vanta config: !`cat .taskmaster/vanta.yaml 2>/dev/null || echo "Not linked"`
- Last sync: !`grep last_sync .taskmaster/vanta.yaml 2>/dev/null | head -1 || echo "Never"`

## Your Task

Use the **Task tool** with `subagent_type='task-agent'` to run the sync.

### If task-master is NOT initialized (.taskmaster directory missing):

Tell the user to initialize task-master first:
```bash
# Use the initialize_project MCP tool or run:
npx task-master-ai init
```

### If Vanta is NOT linked (.taskmaster/vanta.yaml missing):

Run setup wizard:

1. Use `mcp__iniciador-vanta__frameworks` to list available compliance frameworks
2. Present frameworks to user, ask which to track (SOC 2, ISO 27001, etc.)
3. Ask if they have IaC/Terraform repositories for infrastructure fixes
4. Create `.taskmaster/vanta.yaml`:

```yaml
frameworks:
  - framework_id: "<id>"
    name: "<name>"
iac_repos:  # Optional
  - url: "<git_url>"
    type: terraform|terragrunt
linked_at: "<ISO 8601 timestamp>"
last_sync: null
```

5. Run initial sync to import failing controls

### If Vanta IS linked (.taskmaster/vanta.yaml exists):

**PULL (Vanta → task-master):**

1. Read config for tracked frameworks
2. For each framework:
   - Use `mcp__iniciador-vanta__list_framework_controls` to get controls
   - Filter for controls NOT fully passing
3. For each failing control:
   - Check if task-master task exists with `[Vanta:{control_id}]` in title
   - If no match (new failing control):
     - Use `mcp__task-master-ai__add_task` with:
       - title: `[Vanta:{control_id}] {control_name}`
       - description: Framework, control details, remediation guidance
       - priority: mapped from severity (see below)
   - If match exists: update status if control status changed

4. For controls now PASSING that have open tasks:
   - Report: "Control {control_id} is now passing. Consider marking task as done."

5. Update `last_sync` in config

**Priority Mapping:**

| Vanta Severity | Task-Master Priority |
|----------------|---------------------|
| Critical | high |
| High | high |
| Medium | medium |
| Low | low |

**Task Description Template:**
```
Framework: {framework_name}
Control: {control_id}
Status: {status}

{control_description}

Remediation:
{remediation_guidance}

IaC Repos (if applicable):
{iac_repos_from_config}
```

Report sync results:
- New failing controls imported
- Controls now passing (suggest closing tasks)
- Total open compliance tasks
