---
name: architecture-review
description: Comprehensive architecture review of the codebase. Use when the user asks for an architecture review, system design review, or structural analysis.
---

# Architecture Review Workflow

Delegate to an architecture-reviewer agent for comprehensive structural analysis.

## Task for architecture-reviewer agent

Analyze the codebase architecture across all 15 dimensions below. For each dimension, provide:
- Current state assessment (1-5 maturity rating)
- Specific findings with file/module references
- Concrete recommendations

### Review Dimensions

1. **Project Structure** - Directory organization, module boundaries, file naming conventions, separation of concerns
2. **Design Patterns** - Pattern usage, consistency, appropriateness for the domain
3. **Dependency Management** - External dependencies, version management, dependency injection, coupling
4. **Data Management** - Data flow, storage patterns, caching strategy, data validation
5. **Component Design** - Interface design, abstraction levels, reusability, cohesion
6. **Error Handling** - Error propagation, recovery strategies, user-facing errors, logging
7. **Scalability** - Horizontal/vertical scaling readiness, bottlenecks, resource management
8. **Security Architecture** - Auth patterns, data protection, attack surface, secure defaults
9. **Testability** - Test architecture, mockability, test isolation, coverage strategy
10. **Operations** - Observability, deployment, configuration management, health checks
11. **Documentation** - Code documentation, architecture docs, API docs, decision records
12. **Extensibility** - Plugin points, extension mechanisms, backward compatibility
13. **Technology Stack** - Tech choices appropriateness, version currency, ecosystem alignment
14. **Performance** - Performance patterns, resource efficiency, optimization opportunities
15. **Team Alignment** - Code consistency, onboarding ease, convention adherence

### Context gathering

The agent should:
```bash
# Understand project structure
find . -type f -name '*.json' -o -name '*.yaml' -o -name '*.toml' -o -name '*.nix' | head -20
ls -la
# Read key config files (package.json, Cargo.toml, go.mod, flake.nix, etc.)
# Read entry points and main modules
# Check for CI/CD configuration
# Review test structure
```

### Output format

## Executive Summary
2-3 sentence overview of architecture health.

## Maturity Scorecard

| Dimension | Rating | Key Finding |
|-|-|-|
| Structure | 4/5 | Well-organized modules |
| ... | ... | ... |

## Top Concerns
Ranked list of the most impactful architectural issues.

## Prioritized Recommendations
1. **[Critical]** Description and rationale
2. **[High]** Description and rationale
3. **[Medium]** Description and rationale

## Technical Debt Inventory
Identified technical debt items with estimated effort to resolve.
