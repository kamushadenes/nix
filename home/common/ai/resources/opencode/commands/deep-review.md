---
description: Comprehensive code review
agent: code-reviewer
model: anthropic/claude-opus-4-6
---

Run a comprehensive deep review of code changes covering all quality dimensions.

## Context

Current branch: !`git branch --show-current`
Base branch: !`git rev-parse --verify main 2>/dev/null && echo main || echo master`
Changed files: !`git diff $(git rev-parse --verify main 2>/dev/null && echo main || echo master)...HEAD --name-only`
Diff: !`git diff $(git rev-parse --verify main 2>/dev/null && echo main || echo master)...HEAD`

## Review Dimensions

Analyze the changes across ALL of these dimensions:

1. **Code quality** - Correctness, logic errors, edge cases, error handling
2. **Security** - Injection, auth bypass, data exposure, OWASP Top 10
3. **Performance** - N+1 queries, blocking calls, inefficient algorithms
4. **Concurrency** - Race conditions, deadlocks, thread safety
5. **Resource management** - Leaks, unclosed handles, memory issues
6. **Type safety** - Type errors, missing annotations, unsafe casts
7. **Complexity** - Over-abstraction, unnecessary indirection
8. **Dependencies** - Outdated packages, known CVEs

## Output Format

Present findings by severity:
- **Critical Issues** (Must Fix)
- **High Priority** (Should Fix)
- **Medium Priority** (Recommended)
- **Low Priority** (Optional)

Include file:line references and clear fix recommendations for each finding.

$ARGUMENTS
