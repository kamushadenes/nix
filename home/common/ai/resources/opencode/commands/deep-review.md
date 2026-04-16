---
description:
  Comprehensive code review using 9 specialized reviewer subagents with optional
  parallel fix workflow
---

Run a comprehensive deep review using 9 specialized reviewer subagents that
analyze changes in parallel. A suggestion-critic subagent validates results.
Optionally fix validated findings using parallel worktree agents.

## Context

- Current branch:
  !`git branch --show-current 2>/dev/null || echo "detached"`
- Default branch:
  !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main"`
- Uncommitted changes:
  !`git diff --stat HEAD 2>/dev/null | tail -1 || echo "none"`
- Branch diff:
  !`git diff --stat $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")...HEAD 2>/dev/null | tail -1 || echo "none"`

## Phase 1: Review

1. **Ask the user what to review** using the question tool:

   Use the pre-embedded context above to inform the user which scopes have
   changes. Skip scopes with "none".

   Options:
   - "Uncommitted changes" - Review only uncommitted changes (git diff)
   - "Branch changes" - Review all changes on this branch vs main/master
   - "Entire codebase" - Review the full project

2. **Gather review context based on scope:**

   The branch name and default branch are already known from the context above —
   do not re-fetch them.

   - **Uncommitted**: `git diff HEAD` and `git diff --name-only HEAD`
   - **Branch**: `git diff ${default_branch}...HEAD` and changed files (use
     default branch from context)
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

   Provide findings with severity (Critical/High/Medium/Low), file:line references, and fix recommendations.""",
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

   For each finding, tag with originating domain (e.g., security-auditor, code-reviewer).

   Filter for: existence, scope, actionability, false positives, duplicates, scope creep.
   Return validated findings grouped by originating domain and severity + filtered findings with rejection reasons.""",
     description="Validating findings"
   )
   ```

5. **Present validated findings by severity:**

   ```markdown
   ## Deep Review Summary

   **Scope**: [scope]

   ### Critical Issues (Must Fix)

   [findings with domain tags]

   ### High Priority (Should Fix)

   [findings with domain tags]

   ### Medium Priority (Recommended)

   [findings with domain tags]

   ### Low Priority (Optional)

   [findings with domain tags]

   ### Consensus Analysis

   - **All reviewers agree**: [high confidence]
   - **Most agree**: [good confidence]
   - **Divergent views**: [needs human judgment]

   ### Filtered by Critic

   - Validated: Y / Filtered: Z (false positives, out of scope, duplicates)
   ```

## Phase 2: Fix Decision

6. **Ask the user what to fix** using the question tool:

   Options:
   - "Fix all validated findings" - Fix Critical, High, Medium, and Low findings
   - "Fix critical and high only" - Fix only Critical and High severity findings
   - "Skip fixes" - End the review here

   If "Skip fixes", present the review summary and stop. If branch scope and PR
   exists, offer to post findings as PR review comments via `/github-pr-review`.

## Phase 3: Parallel Fix via Worktrees

7. **Group and filter findings for fixing:**
   - Group the validated findings by their originating reviewer domain
   - If user chose "Fix critical and high only", filter to only Critical and
     High severity
   - Drop any domain that has zero findings after filtering
   - Record the current branch name and HEAD commit

   **Detect project language** from changed file extensions to select
   appropriate skills:
   - `.ts`, `.tsx`, `.js`, `.jsx` → `typescript-pro`
   - `.go` → `golang-pro`
   - `.rs` → `rust-engineer`
   - `.py` → `python-pro`
   - `.tf` → `terraform-engineer`

8. **Create a git worktree for each non-empty domain:**

   ```bash
   timestamp=$(date +%s)
   current_branch=$(git branch --show-current)

   # For each domain with findings:
   git worktree add /tmp/deep-review-fix-<domain>-${timestamp} -b fix/<domain>-${timestamp} HEAD
   ```

   Track all created worktree paths and branch names for cleanup.

9. **Spawn parallel fix tasks, one per domain:**

   Launch all fix agents simultaneously. Each works in its own worktree
   directory:

   | Domain                | Category | Reasoning                              |
   | --------------------- | -------- | -------------------------------------- |
   | security-auditor      | `deep`   | Security fixes need careful analysis   |
   | code-reviewer         | `quick`  | Usually straightforward quality fixes  |
   | test-analyzer         | `deep`   | Writing tests requires understanding   |
   | performance-analyzer  | `quick`  | Usually targeted optimizations         |
   | silent-failure-hunter | `quick`  | Adding error handling is mechanical    |
   | type-checker          | `quick`  | Type annotations are targeted          |
   | code-simplifier       | `quick`  | Simplification is localized            |
   | refactoring-advisor   | `deep`   | Refactoring needs structural awareness |
   | dependency-checker    | `quick`  | Version bumps are mechanical           |

   Each fix task:

   ```
   task(
     category="<category-from-table>",
     load_skills=["git-master", "<language-skill-if-detected>"],
     run_in_background=true,
     prompt="""Fix validated review findings in the worktree.

   WORKTREE: /tmp/deep-review-fix-<domain>-<timestamp>
   DOMAIN: <domain>
   WORKING DIRECTORY: You MUST work in the worktree path above, not the main repo.

   ## Findings to Fix

   <list of validated findings for this domain, each with:>
   - Severity
   - File:line reference
   - Description
   - Recommended fix

   ## Instructions

   1. For each finding, apply the recommended fix
   2. After ALL fixes, run lsp_diagnostics on every file you changed
   3. If the project has a build command, run it to verify nothing is broken
   4. Stage all changes: git add -A
   5. Commit with message: fix(<domain-short>): <summary of N fixes applied>
      Example: fix(security): resolve 3 OWASP findings
      Example: fix(types): add missing type annotations to 5 functions

   ## Constraints

   - Work ONLY in the worktree directory
   - Fix ONLY the listed findings — no drive-by improvements
   - If a fix would require changes outside the listed files, note it but skip
   - If a finding cannot be fixed safely, skip it and explain why in commit body""",
     description="Fix: <domain> (<N> findings)"
   )
   ```

10. **Sequential merge back to working branch:**

    After ALL fix tasks complete, merge worktrees back one at a time.

    **Merge order**: `dependency-checker` FIRST (lockfile changes affect
    others), then remaining domains in any order.

    ```bash
    git checkout ${current_branch}

    # For each domain (dependency-checker first):
    git merge fix/<domain>-${timestamp} --no-edit

    # If merge conflict:
    # 1. Attempt auto-resolution
    # 2. If unresolvable, abort merge, report to user, skip this domain
    ```

    Each successful merge preserves the domain's commit (one commit per domain
    in history).

    If a merge fails:
    - `git merge --abort`
    - Log the domain and conflicting files
    - Continue with remaining domains
    - Report skipped domains to user at the end

## Phase 4: Verification

11. **Run suggestion-critic sanity check on combined fix diff:**

    ```
    task(
      subagent_type="suggestion-critic",
      prompt="""Sanity check: validate the combined fix diff doesn't introduce regressions.

    Original review scope: {review_scope}
    Original findings that were fixed: {fixed_findings_summary}

    Combined fix diff (all merged domains):
    {git diff of all fixes vs pre-fix HEAD}

    Check for:
    1. Incomplete fixes (finding addressed but not fully resolved)
    2. Regressions (fix introduces new issues)
    3. Scope violations (changes beyond what was requested)
    4. Consistency (fixes don't contradict each other)

    Return: PASS (all good) or CONCERNS (list specific issues).""",
      description="Sanity check on fixes"
    )
    ```

12. **Clean up worktrees and report:**

    ```bash
    # Remove all worktrees
    git worktree remove /tmp/deep-review-fix-<domain>-${timestamp} --force

    # Delete fix branches
    git branch -D fix/<domain>-${timestamp}
    ```

    Present final report:

    ```markdown
    ## Fix Summary

    **Findings addressed:** X of Y validated findings

    ### Merged Domains

    | Domain           | Findings Fixed | Commit                                                      |
    | ---------------- | -------------- | ----------------------------------------------------------- |
    | security-auditor | 3              | abc1234 fix(security): resolve 3 OWASP findings             |
    | code-reviewer    | 5              | def5678 fix(quality): improve error handling in 5 functions |

    ### Skipped Domains (merge conflicts)

    | Domain   | Reason             |
    | -------- | ------------------ |
    | <domain> | Conflict in <file> |

    ### Sanity Check

    [PASS or CONCERNS with details]

    ### Next Steps

    - Run full test suite to verify
    - Review git log for individual fix commits
    - Use `git revert <hash>` to undo any specific domain's fixes
    ```

## Notes

- 9 reviewer subagents spawned in parallel for review phase
- Fix agents work in isolated git worktrees — no interference between domains
- Dependency fixes merge first to avoid lockfile conflicts
- One commit per domain — easy to revert individual fix categories
- Suggestion-critic validates both review findings and fix quality
- For faster review without fix workflow (4 agents), use `/review` instead

$ARGUMENTS
