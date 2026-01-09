# Vanta Sync Reference

## Config: `.beads/vanta.yaml`

```yaml
frameworks:
  - soc2
  - iso27001
iac_repos:
  - url: git@github.com:org/terraform-infra.git
    type: terraform
linked_at: "<timestamp>"
last_sync: null
```

## Setup (no config exists)

1. `mcp__iniciador-vanta__frameworks` - list frameworks
2. Return structured options (SOC 2, ISO 27001, HIPAA, GDPR)
3. Ask about IaC repos
4. Write `.beads/vanta.yaml`
5. Run initial pull

## Sync Operations

**Pull from Vanta:**
1. Read config for frameworks and iac_repos
2. `mcp__iniciador-vanta__controls` for each framework
3. Filter for failing/incomplete controls
4. Check: `bd list --json | jq '.[] | select(.external_ref == "vanta-{control_id}")'`
5. Create missing: `bd create --title="[Compliance] {name}" --external-ref=vanta-{id} --labels=compliance,{framework}`
6. Report controls now passing with open beads

## Priority Mapping

| Vanta Severity | Beads Priority |
|----------------|----------------|
| Critical | 0 (P0) |
| High | 1 (P1) |
| Medium | 2 (P2) |
| Low | 3 (P3) |

## Field Mapping

| Beads | Vanta |
|-------|-------|
| title | `[Compliance] {control.name}` |
| description | Framework, ID, description, IaC repos |
| external_ref | `vanta-{control_id}` |
| labels | compliance, {framework} |

## IaC Integration

For infrastructure controls:
1. Clone IaC repo to temp folder
2. Make fixes, commit, push, create PR
3. Include `iac_repos` URLs in bead descriptions
