---
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Task
description: Quick code review of branch changes using 4 reviewer teammates
---

Run a focused code review of branch changes using an Agent Team of 4 essential reviewers. For comprehensive review with all 9 agents, use `/deep-review` instead.

## Steps

1. **Determine the base branch:**
   ```bash
   git rev-parse --verify main 2>/dev/null && base_branch="main" || base_branch="master"
   ```

2. **Get branch info and check for changes:**
   ```bash
   current_branch=$(git branch --show-current)
   commit_count=$(git rev-list --count ${base_branch}..HEAD)
   git log ${base_branch}..HEAD --oneline
   ```
   If no changes, inform user and stop.

3. **Get the diff:**
   ```bash
   diff=$(git diff ${base_branch}...HEAD)
   changed_files=$(git diff --name-only ${base_branch}...HEAD)
   ```

4. **Create a review team with 4 essential reviewer teammates:**

   | Teammate | Agent | Focus |
   |----------|-------|-------|
   | 1 | code-reviewer | Code quality, best practices, maintainability |
   | 2 | security-auditor | Security vulnerabilities, OWASP issues |
   | 3 | test-analyzer | Test coverage, missing tests |
   | 4 | silent-failure-hunter | Error handling, swallowed exceptions |

   Each teammate gets the review context (diff, changed files, branch info) and their domain focus. Reviewers can discuss and cross-reference findings.

5. **After all reviewers complete**, run suggestion-critic as a subagent to validate findings.

6. **Present validated findings by severity:**

   ```markdown
   ## Review Summary

   **Branch:** [current_branch] vs [base_branch] ([commit_count] commits)
   **Files changed:** [count]

   ### Critical Issues
   [findings]

   ### High Priority
   [findings]

   ### Medium Priority
   [findings]

   ### Low Priority
   [findings]
   ```

7. **Offer to fix issues** if any Critical or High severity findings exist.

## Agents Used

| Agent | Focus |
|-------|-------|
| code-reviewer | Code quality, best practices, maintainability |
| security-auditor | Security vulnerabilities, OWASP issues |
| test-analyzer | Test coverage, missing tests |
| silent-failure-hunter | Error handling, swallowed exceptions |

## Notes

- 4 reviewer teammates (vs 9 in `/deep-review`) - faster but less comprehensive
- Reviewers can discuss findings across domains
- Suggestion-critic validates after reviewers complete
- For full analysis including performance, types, dependencies, use `/deep-review`
