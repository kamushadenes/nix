---
name: codex-fix-pr
description: Fix PR review feedback and code scanning alerts. Use when the user asks to fix PR comments, address review feedback, resolve PR issues, or fix SAST alerts.
---

# Fix PR Feedback Workflow

Address all review feedback, comments, and code scanning alerts on a PR.

## Step 1: Determine the PR

If the user provided a PR number, use it. Otherwise:
```bash
gh pr view --json number,title,url 2>/dev/null
```
If no PR exists on the current branch, ask the user which PR to fix.

## Step 2: Gather all feedback in parallel

### Review threads (GraphQL with pagination)

```bash
query=$(cat <<'GRAPHQL'
query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          path
          line
          comments(first: 20) {
            nodes {
              body
              author { login }
              createdAt
            }
          }
        }
      }
    }
  }
}
GRAPHQL
)
gh api graphql -f query="$query" -f owner=OWNER -f repo=REPO -F number=NUMBER
```

### Standalone review comments

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate
```

### Code scanning alerts

```bash
gh api repos/{owner}/{repo}/code-scanning/alerts?ref=HEAD --paginate 2>/dev/null
```

## Step 3: Present summary

Show the user a summary of all feedback:
- Total unresolved threads
- Total standalone comments
- Total code scanning alerts
- Grouped by file

## Step 4: Triage feedback

For each piece of feedback, classify as:
- **VALID**: Legitimate issue, will fix
- **INVALID**: Incorrect suggestion, will reply with explanation and resolve
- **OUTDATED**: Already addressed or no longer applicable, will note and resolve

## Step 5: Process fixes

For VALID items, fix file by file, processing line changes from bottom to top (to preserve line numbers):

1. Read the file
2. Apply the fix
3. Verify the fix doesn't break anything

## Step 6: Reply and resolve threads

For each addressed thread:

```bash
# Reply to thread
gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
    comment { id }
  }
}' -f threadId="$THREAD_ID" -f body="Fixed: <description of change>"

# Resolve thread
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}' -f threadId="$THREAD_ID"
```

For INVALID items, reply with technical explanation before resolving.

## Step 7: Commit and push

```bash
git add -A
git commit -m "fix: address PR review feedback

Resolved N review threads, dismissed M as invalid/outdated."
git push
```

## Step 8: Report summary

| Category | Count | Details |
|-|-|-|
| Fixed | N | List of fixes applied |
| Dismissed (invalid) | M | Reasons provided |
| Outdated | O | Already addressed |
| Skipped | P | Requires discussion |
