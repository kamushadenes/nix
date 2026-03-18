# Testing Best Practices

Shared testing patterns across language skills.

## Test Structure (AAA Pattern)

```
Arrange - Set up test data and conditions
Act     - Execute the code under test
Assert  - Verify the results
```

## Test Naming

```
test_<function>_<scenario>_<expected_result>

Examples:
- test_parse_valid_json_returns_object
- test_parse_invalid_json_raises_error
- test_fetch_user_not_found_returns_none
```

## Test Categories

| Type        | Scope           | Speed  | Dependencies    |
|-------------|-----------------|--------|-----------------|
| Unit        | Single function | Fast   | None/mocked     |
| Integration | Multiple units  | Medium | Real components |
| E2E         | Full system     | Slow   | All services    |

## Coverage Guidelines

- **Unit tests**: All public functions, edge cases, error paths
- **Integration tests**: Critical paths, external boundaries
- **E2E tests**: Happy path, critical user journeys

## Mocking Strategy

Mock at boundaries:
- External APIs
- Database calls
- File system
- Time/randomness

## TDD Workflow

1. Write failing test (Red)
2. Write minimal code to pass (Green)
3. Refactor with tests passing (Refactor)

## Language-Specific Notes

Reference language skill's SKILL.md for:
- Test framework conventions
- Mocking libraries
- Coverage tools
- Test runner configuration
