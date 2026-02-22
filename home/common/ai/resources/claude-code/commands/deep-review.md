---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(gh pr:*), Bash(test:*), Task, AskUserQuestion, Skill
description: Comprehensive code review using 9 specialized reviewer teammates
---

Run a comprehensive deep review using an Agent Team of 9 specialized reviewers that can discuss and cross-reference findings. A suggestion-critic subagent validates results after.

## Steps

1. **Ask the user what to review** using AskUserQuestion:

   Options:
   - "Uncommitted changes" - Review only uncommitted changes (git diff)
   - "Branch changes" - Review all changes on this branch vs main/master
   - "Entire codebase" - Review the full project

2. **Gather review context based on scope:**

   - **Uncommitted**: `git diff HEAD` and `git diff --name-only HEAD`
   - **Branch**: Determine base branch, `git diff ${base_branch}...HEAD` and changed files
   - **Codebase**: Identify main source directories

   If no changes found, inform user and stop.

3. **Create a review team with 9 specialized reviewer teammates:**

   Create an Agent Team with these 9 reviewers. Each teammate gets the review context (diff, changed files, scope) plus their domain focus:

   | Teammate | Agent | Focus |
   |----------|-------|-------|
   | 1 | code-reviewer | Code quality, correctness, error handling |
   | 2 | security-auditor | Security vulnerabilities, OWASP |
   | 3 | test-analyzer | Test coverage, missing tests |
   | 4 | performance-analyzer | Performance issues, Big O |
   | 5 | silent-failure-hunter | Swallowed exceptions, error gaps |
   | 6 | type-checker | Type safety, annotations |
   | 7 | code-simplifier | Complexity, over-abstraction |
   | 8 | refactoring-advisor | Refactoring opportunities |
   | 9 | dependency-checker | Dependency health, CVEs |

   Each teammate's spawn prompt:
   ```
   Review these <scope> changes for <domain focus>:

   Changed files: <file list>

   <diff or codebase context>

   Share findings with other reviewers and challenge their conclusions.
   ```

   Reviewers can discuss and cross-reference findings across domains (e.g., security reviewer confirms a performance fix doesn't introduce vulnerabilities).

4. **After all reviewers complete**, run suggestion-critic as a **subagent** (not teammate):

   ```python
   critic = Task(
       subagent_type="suggestion-critic",
       prompt=f"""Validate these aggregated findings from 9 review agents:

   Review scope: {review_scope}
   Changed files: {changed_files}

   ## Aggregated Findings
   {aggregated_findings}

   Filter for: existence, scope, actionability, false positives, duplicates, scope creep.
   Return validated findings by severity + filtered findings with rejection reasons.""",
       description="Validating findings"
   )
   ```

5. **Present validated findings by severity:**

   ```markdown
   ## Deep Review Summary

   **Scope**: [scope]

   ### Critical Issues (Must Fix)
   [findings]

   ### High Priority (Should Fix)
   [findings]

   ### Medium Priority (Recommended)
   [findings]

   ### Low Priority (Optional)
   [findings]

   ### Consensus Analysis
   - **All reviewers agree**: [high confidence]
   - **Most agree**: [good confidence]
   - **Divergent views**: [needs human judgment]

   ### Filtered by Critic
   - Validated: Y / Filtered: Z (false positives, out of scope, duplicates)
   ```

6. **Offer to help address issues found**

7. **If branch scope and PR exists**, offer to post findings as PR review comments via `github-pr-review` skill

8. **If uncommitted scope**, offer to commit via `/commit` skill

## Notes

- 9 reviewer teammates that can discuss findings across domains
- Suggestion-critic runs as subagent after all reviewers complete
- For faster review with 4 agents, use `/review` instead
