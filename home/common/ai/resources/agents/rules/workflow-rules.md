# Workflow Rules

## Planning Mode

- Shift+Tab enters plan mode for complex tasks
- For structured projects, use `/gsd:new-project` or `/gsd:plan-phase`
- Explore without modifying files
- Exit plan mode before making changes

## Todo Tool Blocking

If `todowrite` fails with "Cannot mark task complete with uncommitted changes",
commit the pending changes immediately, then retry the todo operation. Do not
skip todo tracking because of this error.

## Verification

- Run tests after code changes
- Build after significant changes
- Lint before committing
