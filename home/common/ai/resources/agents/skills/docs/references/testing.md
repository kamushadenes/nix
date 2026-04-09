# Testing Documentation

Template for standalone testing documentation.

## Required Sections

### Test Framework and Setup

The testing framework(s) in use and any required setup before running tests.

```markdown
## Test Framework

- **Framework**: [name and version]
- **Runner**: [test runner if different from framework]
- **Assertion library**: [if separate]
- **Coverage tool**: [name]

### Setup

[Any setup required beyond `install` — test databases, env vars, fixtures]
```

### Running Tests

Exact commands to run the full suite, subsets, or individual tests.

```markdown
## Running Tests

| Command | Description |
|-|-|
| `[test command]` | Run full test suite |
| `[unit command]` | Run unit tests only |
| `[integration command]` | Run integration tests |
| `[watch command]` | Run in watch mode |
| `[single command]` | Run a single test file |
```

### Writing New Tests

File naming conventions, test helper patterns, and where to put new tests.

```markdown
## Writing Tests

### File Naming

- Unit tests: `[pattern]` (e.g., `*.test.ts`, `*_test.go`)
- Integration tests: `[pattern]`
- Location: `[where test files live relative to source]`

### Test Helpers

- `[helper file]` — [purpose]

### Patterns

[Show a minimal example of a well-structured test using the project's actual
patterns — copy from an existing test file]
```

### Coverage

Coverage thresholds and how to check them.

```markdown
## Coverage

### Thresholds

| Type | Minimum |
|-|-|
| Lines | [X]% |
| Branches | [X]% |
| Functions | [X]% |

### Generating Reports

\`\`\`bash
[coverage command]
\`\`\`
```

### CI Integration

How tests run in CI — workflow name, triggers, and commands.

```markdown
## CI

Tests run automatically on [trigger]. See `[workflow file]`.

[Include Mermaid diagram if the test pipeline has multiple stages:]

\`\`\`mermaid
flowchart LR
    Push --> Lint --> Unit[Unit Tests] --> Integration[Integration Tests]
    Integration --> Coverage[Coverage Check] --> Report
\`\`\`
```

## Content Discovery

- **Framework detection**: Check `package.json` devDependencies for `jest`,
  `vitest`, `mocha`, `pytest`; check for `jest.config.*`, `vitest.config.*`,
  `.mocharc.*`; check `go.mod` for `testing`; check `Cargo.toml` for
  `[dev-dependencies]`
- **Test commands**: Read `package.json` `scripts.test*`, `Makefile` test
  targets, CI workflow test steps
- **Naming patterns**: Glob for `*.test.*`, `*.spec.*`, `*_test.*`, `test_*.*`
  to discover the convention; check test directories (`tests/`, `test/`,
  `__tests__/`, `spec/`)
- **Coverage config**: Read `jest.config.*` `coverageThreshold`, `vitest.config.*`
  coverage section, `.nycrc`, `c8` config, `.coveragerc`, `setup.cfg`
- **CI integration**: Read `.github/workflows/*.yml`, `.gitlab-ci.yml`,
  `Jenkinsfile` for test steps
- **Test helpers**: Grep for shared setup files (`setup.*`, `helpers.*`,
  `fixtures.*`, `conftest.py`) in test directories
