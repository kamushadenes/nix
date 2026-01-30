---
allowed-tools: Bash(gh:*), Bash(git:*), Read, Write
description: Review a GitHub PR with inline comments and code suggestions
---

## Context

- Repository: !`gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null`
- Current branch: !`git branch --show-current`

## Your task

Review PR **$ARGUMENTS** and submit a GitHub review with inline comments.

### 1. Gather context

```bash
gh pr view $ARGUMENTS --json number,title,body,headRefName,baseRefName,headRefOid,files
gh pr diff $ARGUMENTS
```

Read changed files as needed for full context around the diff.

### 2. Analyze changes

Review for substantive issues: bugs, security problems, logic errors, missing error handling at boundaries, performance concerns. Skip style nitpicks and formatting.

### 3. Build and submit the review

Write a review JSON file to the scratchpad directory, then submit via the API.

**Position calculation (common pitfall):** Positions are diff-relative, NOT absolute line numbers. Count every line from the first line after each `@@` hunk header (that first line = position 1). Context lines, additions, and deletions all count. To verify positions:

```bash
gh pr diff $ARGUMENTS -- path/to/file | cat -n
```

**Review JSON format:**

```json
{
  "commit_id": "<headRefOid from step 1>",
  "body": "Summary of findings",
  "event": "COMMENT | APPROVE | REQUEST_CHANGES",
  "comments": [
    {
      "path": "relative/file/path",
      "position": 42,
      "body": "Description.\n\n```suggestion\nreplacement code\n```"
    }
  ]
}
```

**Submit:**

```bash
gh api --method POST repos/{owner}/{repo}/pulls/{number}/reviews --input review.json
```

### Notes

- Use `suggestion` blocks only for simple, unambiguous fixes. Describe complex changes in prose.
- Group related findings when they share a root cause.
- If the API returns "line could not be resolved", recheck position against `gh pr diff ... | cat -n`.
- If "user_id can only have one pending review", submit the pending review first or add comments individually via `repos/{owner}/{repo}/pulls/{number}/comments`.
