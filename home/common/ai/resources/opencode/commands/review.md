---
description: Quick code review of branch changes
agent: code-reviewer
---

Review the changes on this branch compared to the base branch.

## Context

Current branch: !`git branch --show-current`
Base branch: !`git rev-parse --verify main 2>/dev/null && echo main || echo master`
Changed files: !`git diff $(git rev-parse --verify main 2>/dev/null && echo main || echo master)...HEAD --name-only`

## Task

1. Review all changed files for code quality issues
2. Focus on: correctness, error handling, security, performance
3. Provide findings with severity levels and file:line references
4. Summarize with top priorities and positive aspects

$ARGUMENTS
