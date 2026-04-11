---
name: github-pr-review
description: Review a GitHub PR with inline comments and code suggestions. Use when the user asks to review a specific PR, add review comments, or submit a PR review.
---

# PR Review Workflow

Review a GitHub PR and submit inline comments with code suggestions.

## Step 1: Gather PR context

```bash
# Get PR details
gh pr view {number} --json title,body,baseRefName,headRefName,files,additions,deletions

# Get the diff
gh pr diff {number}
```

If the user didn't provide a PR number, check for a PR on the current branch:
```bash
gh pr view --json number 2>/dev/null
```

## Step 2: Read changed files for full context

For each changed file in the diff, read the full file to understand the broader context beyond just the changed lines.

## Step 3: Analyze the changes

Focus on substantive issues only:
- **Bugs**: Logic errors, off-by-one, null dereferences
- **Security**: Injection, auth bypass, data exposure
- **Logic errors**: Incorrect conditions, wrong variable, missing cases
- **Missing error handling**: Unhandled exceptions, missing validation
- **Performance**: N+1 queries, unnecessary allocations, blocking calls

**Skip**: Style nitpicks, formatting preferences, naming opinions (unless truly confusing).

## Step 4: Build review JSON

Create a review payload with position-based comments:

```json
{
  "body": "## Review Summary\n\nOverall assessment...",
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/example.ts",
      "position": 15,
      "body": "**Bug**: Description\n\n```suggestion\nfixed code here\n```"
    }
  ]
}
```

### Position calculation

The `position` field is **diff-relative**, not file-relative:
- Position 1 = first line of the diff hunk (the `@@` line)
- Count downward through the diff including context lines, additions, and deletions
- Only added (`+`) and context (` `) lines can receive comments
- Deleted (`-`) lines cannot receive comments

To calculate: parse the diff output, count lines from each `@@` hunk header, and map file line numbers to diff positions.

## Step 5: Submit the review

Write the review JSON to a temp file and submit:

```bash
cat > /tmp/review.json << 'EOF'
{
  "body": "...",
  "event": "COMMENT",
  "comments": [...]
}
EOF

gh api --method POST repos/{owner}/{repo}/pulls/{number}/reviews --input /tmp/review.json
rm /tmp/review.json
```

Use `"event": "COMMENT"` for neutral review, `"REQUEST_CHANGES"` if there are critical issues, or `"APPROVE"` if the code looks good.

## Step 6: Report

Summarize:
- Total comments posted
- Severity breakdown
- Overall assessment
- Whether changes were requested or the PR was approved
