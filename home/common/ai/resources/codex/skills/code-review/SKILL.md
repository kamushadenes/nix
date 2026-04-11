---
name: code-review
description: Quick code review of uncommitted changes using 3 reviewer agents. Use when the user asks for a code review of current changes, review uncommitted work, or check code quality.
---

# Quick Code Review Workflow

Review uncommitted changes using 3 specialized reviewer agents.

## Step 1: Check for changes

Run `git status --short` to verify there are uncommitted changes. If clean, inform the user there's nothing to review.

## Step 2: Gather the diff

```bash
git diff HEAD
```

If there are staged-only changes, also run `git diff --staged`.

Combine into a single diff for review.

## Step 3: Spawn 3 reviewer agents

Spawn the following agents in parallel, giving each the full diff:

### Agent 1: Security Auditor
Focus areas:
- Injection vulnerabilities (SQL, command, path traversal)
- Authentication/authorization issues
- Secrets or credentials in code
- Input validation gaps
- Unsafe deserialization
- SSRF, XSS, CSRF risks

### Agent 2: Code Reviewer
Focus areas:
- Logic errors and edge cases
- Error handling gaps
- Race conditions
- Resource leaks
- API contract violations
- Missing null/undefined checks

### Agent 3: Silent Failure Hunter
Focus areas:
- Swallowed exceptions (empty catch blocks)
- Ignored return values
- Missing error propagation
- Callbacks that silently fail
- Logging gaps for error paths
- Timeouts without fallbacks

Each agent should return findings in this format:
```
[SEVERITY] file:line - Description
  Context: <relevant code snippet>
  Suggestion: <how to fix>
```

Severity levels: CRITICAL, WARNING, SUGGESTION, POSITIVE

## Step 4: Present findings

Collect all findings and present organized by severity:

### Critical Issues
(items that must be fixed before committing)

### Warnings
(items that should be addressed)

### Suggestions
(nice-to-have improvements)

### Positive Notes
(good patterns observed)

## Step 5: Offer to help

Ask the user if they'd like help fixing any of the identified issues.
