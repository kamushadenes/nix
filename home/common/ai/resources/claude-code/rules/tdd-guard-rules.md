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
