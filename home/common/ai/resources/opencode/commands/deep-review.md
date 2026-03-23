---
description: Comprehensive code review using 9 specialized reviewer subagents
---

Run a comprehensive deep review using 9 specialized reviewer subagents that
analyze changes in parallel. A suggestion-critic subagent validates results
after.

## Steps

1. **Ask the user what to review** using the question tool:

   Options:
   - "Uncommitted changes" - Review only uncommitted changes (git diff)
   - "Branch changes" - Review all changes on this branch vs main/master
   - "Entire codebase" - Review the full project

2. **Gather review context based on scope:**
   - **Uncommitted**: `git diff HEAD` and `git diff --name-only HEAD`
   - **Branch**: Determine base branch, `git diff ${base_branch}...HEAD` and
     changed files
   - **Codebase**: Identify main source directories

   If no changes found, inform user and stop.

3. **Spawn 9 specialized reviewer subagents in parallel:**

   Launch all 9 reviewers simultaneously using task(). Each gets the review
   context (diff, changed files, scope) plus their domain focus:

   | #   | Subagent              | Focus                                     |
   | --- | --------------------- | ----------------------------------------- |
   | 1   | code-reviewer         | Code quality, correctness, error handling |
   | 2   | security-auditor      | Security vulnerabilities, OWASP           |
   | 3   | test-analyzer         | Test coverage, missing tests              |
   | 4   | performance-analyzer  | Performance issues, Big O                 |
   | 5   | silent-failure-hunter | Swallowed exceptions, error gaps          |
   | 6   | type-checker          | Type safety, annotations                  |
   | 7   | code-simplifier       | Complexity, over-abstraction              |
   | 8   | refactoring-advisor   | Refactoring opportunities                 |
   | 9   | dependency-checker    | Dependency health, CVEs                   |

   Each subagent's spawn call:

   ```
   task(
     subagent_type="<agent-name>",
     run_in_background=true,
     prompt="""Review these <scope> changes for <domain focus>:

   Changed files: <file list>

   <diff or codebase context>

   Provide findings with severity, file:line references, and fix recommendations.""",
     description="Review: <domain>"
   )
   ```

4. **After all 9 reviewers complete**, aggregate findings and run
   suggestion-critic as a subagent:

   ```
   task(
     subagent_type="suggestion-critic",
     prompt="""Validate these aggregated findings from 9 review agents:

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

7. **If branch scope and PR exists**, offer to post findings as PR review
   comments via `/github-pr-review`

8. **If uncommitted scope**, offer to commit via `/commit`

## Notes

- 9 reviewer subagents spawned in parallel for maximum throughput
- Suggestion-critic runs as subagent after all reviewers complete
- For faster review with 4 agents, use `/review` instead

$ARGUMENTS
