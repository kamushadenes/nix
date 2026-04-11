---
name: review
description: Code review of branch changes using 4 reviewer agents. Use when the user asks for a branch review, review changes for PR, or review branch vs main.
---

# Branch Code Review Workflow

Review all branch changes against the base branch using 4 specialized agents.

## Step 1: Determine base branch

```bash
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

Fall back to `main`, then `master` if the above fails.

## Step 2: Gather branch context

```bash
# Branch info
git rev-parse --abbrev-ref HEAD
git log --oneline $(git merge-base HEAD origin/${base_branch})..HEAD

# Full diff against base
git diff ${base_branch}...HEAD

# Changed file list
git diff ${base_branch}...HEAD --stat
```

## Step 3: Spawn 4 reviewer agents

Spawn these agents in parallel, giving each the full diff and changed file list:

### Agent 1: Code Reviewer
Focus: Logic errors, edge cases, error handling, race conditions, resource leaks, API contract violations, missing null checks, code clarity.

### Agent 2: Security Auditor
Focus: Injection vulnerabilities, auth issues, secrets in code, input validation, unsafe deserialization, SSRF/XSS/CSRF, dependency vulnerabilities.

### Agent 3: Test Analyzer
Focus: Test coverage for new code, missing edge case tests, test quality, mocking correctness, assertion completeness, regression test gaps.

### Agent 4: Silent Failure Hunter
Focus: Swallowed exceptions, ignored return values, missing error propagation, silent callback failures, logging gaps, timeouts without fallbacks.

Each agent returns findings as:
```
[SEVERITY] file:line - Description
  Context: <code snippet>
  Suggestion: <fix>
```

## Step 4: Validate findings

After all 4 agents complete, run a suggestion-critic agent to validate findings:
- Remove false positives
- Remove suggestions that contradict project conventions
- Verify that suggested fixes are correct
- Flag any findings the critic disagrees with

## Step 5: Present validated findings

Organize by severity:

### Critical Issues
(must fix before merging)

### Warnings
(should address)

### Suggestions
(nice-to-have)

### Positive Notes
(good patterns)

Include consensus notes where multiple reviewers flagged the same issue.

## Step 6: Offer to fix

Ask the user if they'd like help fixing Critical or High severity issues.
