---
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Task, TodoWrite
description: Quick code review of branch changes using 4 key agents
---

Run a focused code review of branch changes against main using 4 essential agents. For comprehensive review with all 9 agents, use `/deep-review` instead.

## Steps

1. **Determine the base branch:**

```bash
git rev-parse --verify main 2>/dev/null && base_branch="main" || base_branch="master"
```

2. **Get branch info:**

```bash
current_branch=$(git branch --show-current)
commit_count=$(git rev-list --count ${base_branch}..HEAD)
```

3. **Check for changes:**

```bash
git log ${base_branch}..HEAD --oneline
```

If no changes, inform the user and stop:

> No changes found between current branch and ${base_branch}.

4. **Get the diff:**

```bash
diff=$(git diff ${base_branch}...HEAD)
changed_files=$(git diff --name-only ${base_branch}...HEAD)
```

5. **Launch 4 key review agents in parallel:**

```python
review_context = f"Review branch changes ({commit_count} commits on {current_branch} vs {base_branch}):\n\nChanged files: {changed_files}\n\n{diff}"

# Essential agents only
code_reviewer = Task(
    subagent_type="code-reviewer",
    prompt=f"Review these branch changes for code quality issues:\n\n{review_context}",
    description="Code quality review"
)

security_auditor = Task(
    subagent_type="security-auditor",
    prompt=f"Review these branch changes for security vulnerabilities:\n\n{review_context}",
    description="Security audit"
)

test_analyzer = Task(
    subagent_type="test-analyzer",
    prompt=f"Review these branch changes - analyze test coverage:\n\n{review_context}",
    description="Test analysis"
)

silent_failure_hunter = Task(
    subagent_type="silent-failure-hunter",
    prompt=f"Review these branch changes for silent failures and missing error handling:\n\n{review_context}",
    description="Error handling review"
)
```

6. **Present findings by severity:**

```markdown
## Review Summary

**Branch:** [current_branch] vs [base_branch] ([commit_count] commits)
**Files changed:** [count]

### Critical Issues

[Issues that must be fixed]

### High Priority

[Issues that should be fixed]

### Medium Priority

[Recommended improvements]

### Low Priority

[Optional suggestions]
```

7. **Offer to fix issues** if any Critical or High severity findings exist.

## Agents Used

| Agent                 | Focus                                         |
| --------------------- | --------------------------------------------- |
| code-reviewer         | Code quality, best practices, maintainability |
| security-auditor      | Security vulnerabilities, OWASP issues        |
| test-analyzer         | Test coverage, missing tests                  |
| silent-failure-hunter | Error handling, swallowed exceptions          |

## Notes

- Runs 4 agents vs 9 in `/deep-review` - faster but less comprehensive
- Each agent uses 3 AI models (claude, codex, gemini) for consensus
- Total of 12 model invocations (vs 27 in deep-review)
- For full analysis including performance, types, dependencies, use `/deep-review`
