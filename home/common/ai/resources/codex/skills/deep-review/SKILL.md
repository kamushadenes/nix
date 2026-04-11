---
name: deep-review
description: Comprehensive code review using 9 specialized reviewer agents. Use when the user asks for a deep review, thorough code review, or comprehensive analysis. For faster review, suggest codex-review instead.
---

# Deep Code Review Workflow

Comprehensive review using 9 specialized agents for thorough analysis.

## Step 1: Determine scope

Ask the user what to review:
- **uncommitted**: Review `git diff HEAD`
- **branch**: Review `git diff ${base_branch}...HEAD`
- **codebase**: Review key files and architecture

If the user doesn't specify, default to branch changes if on a feature branch, otherwise uncommitted changes.

## Step 2: Gather context

Based on scope, collect:

```bash
# For uncommitted
git diff HEAD

# For branch
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git diff ${base_branch}...HEAD
git log --oneline $(git merge-base HEAD origin/${base_branch})..HEAD

# For codebase
# Read key files, package configs, entry points
```

Also gather:
```bash
git diff ${scope} --stat   # Changed files summary
```

## Step 3: Spawn 9 reviewer agents

Spawn all agents in parallel, each receiving the review context and their focus area:

### Agent 1: Code Reviewer
Logic errors, edge cases, error handling, race conditions, resource leaks, API contracts.

### Agent 2: Security Auditor
Injection, auth, secrets, input validation, SSRF/XSS/CSRF, unsafe patterns.

### Agent 3: Test Analyzer
Coverage gaps, missing edge case tests, test quality, mocking correctness, assertions.

### Agent 4: Performance Analyzer
Algorithm complexity, unnecessary allocations, N+1 queries, missing caching, blocking operations, memory leaks.

### Agent 5: Silent Failure Hunter
Swallowed exceptions, ignored returns, missing error propagation, logging gaps.

### Agent 6: Type Checker
Type safety, implicit coercions, generic misuse, null safety, type narrowing gaps.

### Agent 7: Code Simplifier
Unnecessary complexity, over-abstraction, dead code, redundant logic, opportunities to simplify.

### Agent 8: Refactoring Advisor
Code duplication, single responsibility violations, coupling issues, naming, module boundaries.

### Agent 9: Dependency Checker
Outdated dependencies, known vulnerabilities, unused dependencies, version conflicts, license issues.

Each agent returns findings as:
```
[SEVERITY] file:line - Description
  Context: <code snippet>
  Suggestion: <fix>
  Confidence: HIGH/MEDIUM/LOW
```

## Step 4: Validate findings

After all 9 agents complete, run a suggestion-critic agent:
- Remove false positives
- Remove findings that contradict project conventions
- Verify suggested fixes are correct
- Flag disagreements
- Note consensus (issues flagged by multiple agents)

## Step 5: Present validated findings

### Executive Summary
Brief overview of code health across all dimensions.

### Critical Issues
Must fix. Include consensus markers if multiple agents flagged the same issue.

### Warnings
Should address.

### Suggestions
Nice-to-have improvements.

### Positive Notes
Good patterns and practices observed.

### Consensus Analysis
Issues identified by 2+ agents, indicating higher confidence.

## Step 6: Offer next steps

- Fix Critical/High issues
- Post findings as PR review comments (if applicable)
- Generate a detailed report
