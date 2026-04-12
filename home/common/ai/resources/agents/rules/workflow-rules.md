# Workflow Rules

## Todo Tool Blocking (OVERRIDES default no-commit policy)

If `todowrite` fails with "Cannot mark task complete with uncommitted changes",
you MUST commit the pending changes immediately, then retry the todo operation.
This is an EXPLICIT exception to the "never commit without user request" rule.
The user has configured a plugin that enforces atomic commits per task — when it
blocks, committing IS the user's pre-authorized intent. Do not ask for
permission, do not skip todo tracking, just commit and retry.

## Verification

- Run tests after code changes
- Build after significant changes
- Lint before committing
