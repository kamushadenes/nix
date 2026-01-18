# TDD Guard Rules

You must follow Test-Driven Development (TDD) strictly. The TDD cycle has three phases:

## Red Phase

Write ONE failing test that describes desired behavior. The test must fail for the correct reason, not due to syntax errors. Single test additions are always permitted when starting new features.

## Green Phase

Write MINIMAL code to make the test pass. Only implement what's necessary to address the current failure. Avoid anticipatory coding or extra features.

## Refactor Phase

Improve code structure while keeping tests green. Only refactor when relevant tests pass. Both implementation and test code are fair game, but no refactoring with failing tests.

## Core Violations to Avoid

1. **Multiple Test Addition** - Never add multiple new tests simultaneously (except during initial setup)
2. **Over-Implementation** - Never write code exceeding what's needed to pass the current failing test, including untested features or methods
3. **Premature Implementation** - Never add logic before tests exist and fail properly

## Key Guidance

- Stubs are acceptable when tests fail due to missing imports/constructors
- No new logic without failing tests, but stubs supporting test infrastructure are fine
- Refactoring allows types, interfaces, constants, and abstractions without introducing new behavior
- If blocked, create simple stubs first

## Handling TDD Guard Failures

When tdd-guard denies your file writes:

1. **First denial**: Review the violation message carefully, understand which TDD rule was broken, and adjust your approach
2. **Second denial**: Re-examine your changes - ensure you're only writing what's needed for the current phase (red/green/refactor)
3. **Third+ consecutive denial**: If tdd-guard still blocks after multiple attempts and doesn't seem to be tracking your changes correctly, **give up on the standard approach** and use alternative methods:
   - Use `Bash` with `cat` heredoc to write files directly
   - Use `Bash` with `echo` to write smaller files
   - These bypass the Edit/Write tools that tdd-guard monitors

This fallback exists because tdd-guard may occasionally fail to see file changes correctly due to timing or state issues. Don't get stuck in an infinite denial loop.

## Using tdd-guard-go (Go Projects)

For Go projects, use the `tdd-guard-go` reporter to validate TDD compliance:

```bash
# Basic usage - pipe go test JSON output
go test -json ./... 2>&1 | tdd-guard-go

# When running tests from a subdirectory, specify project root
go test -json ./... 2>&1 | tdd-guard-go -project-root /absolute/path/to/project

# Makefile integration example
test:
	go test -json ./... 2>&1 | tdd-guard-go -project-root $(shell pwd)
```

Configuration notes:

- The `-project-root` flag must use an absolute path
- Current directory must be within the configured project root
- Falls back to current directory if not specified

## Using tdd-guard-pytest (Python Projects)

For Python projects, use the `tdd-guard-pytest` reporter to validate TDD compliance:

```bash
# Basic usage - pytest will automatically use the plugin when installed
pytest

# The plugin activates when running pytest in any project
```

Configure the project root in `pyproject.toml`:

```toml
[tool.pytest.ini_options]
tdd_guard_project_root = "/absolute/path/to/project"
```

Configuration notes:

- The `tdd-guard-pytest` plugin is installed via Nix (see `home/common/dev/python.nix`)
- Specify the project root path when tests run from a subdirectory or in a monorepo setup
- Alternative configuration methods: `pytest.ini` or `setup.cfg`
- The reporter integrates automatically with pytest once installed

## Using tdd-guard-vitest (TypeScript Projects)

For TypeScript projects using Vitest, use the `tdd-guard-vitest` reporter to validate TDD compliance:

```bash
# Install in your project
npm install --save-dev tdd-guard-vitest
```

Configure in `vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config'
import { VitestReporter } from 'tdd-guard-vitest'

export default defineConfig({
  test: {
    reporters: ['default', new VitestReporter()],
  },
})
```

For monorepo/workspace projects, specify the project root:

```typescript
import { defineConfig } from 'vitest/config'
import { VitestReporter } from 'tdd-guard-vitest'
import path from 'path'

export default defineConfig({
  test: {
    reporters: ['default', new VitestReporter(path.resolve(__dirname))],
  },
})
```

Configuration notes:

- Requires Vitest 3.2.0 or newer
- The `tdd-guard-vitest` package is installed via Nix on Linux (see `home/common/dev/node.nix`)
- On macOS, install via `npm install -g tdd-guard-vitest` or per-project
- Test results are saved to `.claude/tdd-guard/data/test.json` for TDD Guard validation
- Pass an absolute path to the constructor when tests run from a subdirectory
