---
description: Sync Vanta compliance controls with beads for remediation tracking
---

## Context

- Beads initialized: !`test -d .beads && echo "yes" || echo "no"`
- Vanta linked: !`test -f .beads/vanta.yaml && echo "yes" || echo "no"`
- Link config: !`cat .beads/vanta.yaml 2>/dev/null || echo "Not linked"`
- Last sync: !`grep last_sync .beads/vanta.yaml 2>/dev/null | head -1 || echo "Never"`

## Your Task

You are running the Vanta compliance sync workflow. Use the Task tool to spawn the `task-agent` with the appropriate prompt based on the context above.

### If beads is NOT initialized (.beads directory missing):

Tell the user to run `bd init` first to initialize beads in this repository.

### If Vanta is NOT linked (.beads/vanta.yaml missing):

Spawn task-agent with this prompt:

```
Run Vanta sync SETUP mode (vanta-sync).

1. Use mcp__iniciador-vanta__frameworks to list all available compliance frameworks
2. Present the frameworks to the user and ask which ones to track (SOC 2, ISO 27001, etc.)
3. Ask the user if they have IaC/Terraform repositories for infrastructure fixes:
   - If yes, collect git URLs (e.g., git@github.com:org/terraform-infra.git)
   - After collecting URLs, we'll detect the type (terraform/terragrunt) based on files present
4. Write the configuration to .beads/vanta.yaml:
   ```yaml
   frameworks:
     - <framework_id_1>
     - <framework_id_2>
   iac_repos:  # Optional, only if user provided URLs
     - url: <git_url>
       type: terraform|terragrunt
   linked_at: "<ISO 8601 timestamp>"
   last_sync: null
   ```
5. Run an initial pull to import failing controls as beads issues

This is the setup wizard - be interactive and helpful.
```

### If Vanta IS linked (.beads/vanta.yaml exists):

Spawn task-agent with this prompt:

```
Run Vanta sync SYNC mode (vanta-sync).

Read .beads/vanta.yaml for the tracked frameworks and iac_repos.

PULL: Fetch failing controls from Vanta
1. For each framework in the config:
   - Use mcp__iniciador-vanta__controls to get controls for that framework
   - Filter for controls that are NOT fully passing (need attention)
2. For each failing control:
   - Check if bead exists: bd list --json | jq '.[] | select(.external_ref == "vanta-{control_id}")'
   - If no match (new failing control):
     bd create --title="[Compliance] {control_name}" \
       --type=task \
       --external-ref=vanta-{control_id} \
       --priority=<mapped_priority> \
       --labels=compliance,{framework} \
       --description="Framework: {framework}\nControl: {control_id}\n\n{control_description}\n\nIaC Repos: {iac_repos_from_config}"
   - If match exists: compare status, update bead if control status changed

3. For controls now passing with open beads:
   - Report: "Control {control_id} is now passing. Consider closing bead {bead_id}."

4. Update .beads/vanta.yaml with last_sync: <current_timestamp>

Priority mapping:
- Critical -> 0 (P0)
- High -> 1 (P1)
- Medium -> 2 (P2)
- Low -> 3 (P3)

Report what was synced when complete.
```

## Important

- Do not run tools directly - spawn task-agent to do the work
- Task-agent has access to Vanta MCP tools and bd CLI
- Report the task-agent's results when it completes
- For infrastructure-related controls, include iac_repos URLs in the description
