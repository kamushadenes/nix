---
description: Quick code review of branch changes using 4 reviewer subagents
---

Run a focused code review of branch changes using 4 essential reviewer
subagents. For comprehensive review with all 9 agents, use `/deep-review`
instead.

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

4. **Spawn 4 essential reviewer subagents in parallel:**

   Launch all 4 reviewers simultaneously using task():

   | #   | Subagent              | Focus                                         |
   | --- | --------------------- | --------------------------------------------- |
   | 1   | code-reviewer         | Code quality, best practices, maintainability |
   | 2   | security-auditor      | Security vulnerabilities, OWASP issues        |
   | 3   | test-analyzer         | Test coverage, missing tests                  |
   | 4   | silent-failure-hunter | Error handling, swallowed exceptions          |

   Each subagent gets the review context (diff, changed files, branch info) and
   their domain focus:

   ```
   task(
     subagent_type="<agent-name>",
     run_in_background=true,
     prompt="""Review these branch changes for <domain focus>:

   Branch: {current_branch} vs {base_branch} ({commit_count} commits)
   Changed files: {changed_files}

   {diff}

   Provide findings with severity, file:line references, and fix recommendations.""",
     description="Review: <domain>"
   )
   ```

5. **After all reviewers complete**, aggregate findings and run
   suggestion-critic as a subagent to validate:

   ```
   task(
     subagent_type="suggestion-critic",
     prompt="""Validate these aggregated findings from 4 review agents:

   Branch: {current_branch} vs {base_branch}
   Changed files: {changed_files}

   ## Aggregated Findings
   {aggregated_findings}

   Filter for: existence, scope, actionability, false positives, duplicates, scope creep.
   Return validated findings by severity + filtered findings with rejection reasons.""",
     description="Validating findings"
   )
   ```

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

| Agent                 | Focus                                         |
| --------------------- | --------------------------------------------- |
| code-reviewer         | Code quality, best practices, maintainability |
| security-auditor      | Security vulnerabilities, OWASP issues        |
| test-analyzer         | Test coverage, missing tests                  |
| silent-failure-hunter | Error handling, swallowed exceptions          |

## Notes

- 4 reviewer subagents (vs 9 in `/deep-review`) - faster but less comprehensive
- Suggestion-critic validates after reviewers complete
- For full analysis including performance, types, dependencies, use
  `/deep-review`

$ARGUMENTS
