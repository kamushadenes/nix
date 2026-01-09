# TDD Guard Rules

Follow TDD strictly: Red → Green → Refactor

## Phases

- **Red**: Write ONE failing test (must fail for correct reason)
- **Green**: Minimal code to pass, no extra features
- **Refactor**: Improve structure only when tests pass

## Violations

- Multiple test additions (except initial setup)
- Over-implementation beyond current test
- Logic before failing tests exist

## Guidance

- Stubs OK for missing imports/constructors
- Types/interfaces/constants OK during refactor
- If blocked, create stubs first

## Tools

- **Go**: `go test -json ./... | tdd-guard-go -project-root /path`
- **Python**: pytest auto-activates; set `tdd_guard_project_root` in pyproject.toml
