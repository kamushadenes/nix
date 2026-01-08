# Workflow Rules

## Planning Mode

- Shift+Tab enters plan mode for complex tasks
- Explore without modifying files
- Exit plan mode before making changes

## Task Management

- Use `bd` (beads) for ALL task tracking (see beads-rules.md)
- TodoWrite is for execution steps WITHIN a beads issue
- Update beads status as you work (`bd update`, `bd close`)
- Only mark complete when verified AND beads issue closed
- If `.beads/clickup.yaml` exists, run `/clickup-sync` to sync with ClickUp

## Verification

- Run tests after code changes
- Build after significant changes
- Lint before committing
