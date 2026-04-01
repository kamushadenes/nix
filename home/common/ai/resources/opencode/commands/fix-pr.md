---
description: Fix PR review feedback and code scanning alerts
argument-hint: "[PR-URL-or-number]"
---

## Context

- Repo:
  !`gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo "unknown"`
- Default branch:
  !`gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main"`
- Current branch PR:
  !`gh pr view --json number,url,headRefName 2>/dev/null || echo "no-pr"`

## Your Task

Fix all actionable feedback on a PR: human review conversations, standalone
review comments, and code scanning (SAST) alerts.

### Step 1: Determine the PR

Parse `$ARGUMENTS` to get the PR:

- If URL (contains `github.com`): extract owner/repo and PR number
- If number: use current repo
- If empty: use current branch's PR (from context above)

### Step 2: Gather All Feedback

Run the following fetches in parallel.

#### 2a: Fetch Unresolved Review Threads (with Pagination)

**IMPORTANT**: PRs can have more than 100 review threads. You MUST handle
pagination.

**IMPORTANT**: Use heredoc syntax to avoid shell escaping issues with exclamation
marks in GraphQL types (String!, Int!, ID!):

```bash
query=$(cat <<'EOF'
query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $cursor) {
        totalCount
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          path
          line
          startLine
          diffSide
          comments(first: 10) {
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
EOF
)
gh api graphql -f query="$query" -f owner=OWNER -f repo=REPO -F pr=NUMBER
```

**Pagination**: If `pageInfo.hasNextPage` is true, fetch the next page by adding
`-f cursor=ENDCURSOR`. Repeat until all pages collected.

**Filter client-side**: GitHub's `reviewThreads` doesn't support server-side
filtering. Use `jq` to filter:

```bash
| jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .path != null)]'
```

#### 2b: Fetch Standalone Review Comments

Reviews can have top-level body text with action items not tied to specific
threads. Fetch these too:

```bash
query=$(cat <<'EOF'
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviews(first: 100, states: [CHANGES_REQUESTED, COMMENTED]) {
        nodes {
          id
          body
          author { login }
          state
          createdAt
        }
      }
    }
  }
}
EOF
)
gh api graphql -f query="$query" -f owner=OWNER -f repo=REPO -F pr=NUMBER
```

Filter out reviews with empty bodies — only keep those with substantive action
items:

```bash
| jq '[.data.repository.pullRequest.reviews.nodes[] | select(.body != null and .body != "" and (.body | length) > 10)]'
```

#### 2c: Fetch Code Scanning Alerts

Fetch SAST alerts for the PR's head branch. This may return empty or 404 if code
scanning is not enabled — that's fine, just skip SAST processing.

```bash
gh api --paginate "repos/OWNER/REPO/code-scanning/alerts?ref=refs/heads/HEAD_BRANCH&state=open&per_page=100"
```

### Step 3: Present Summary

Show the user:

- PR number and title
- Number of unresolved review threads
- Number of standalone review comments with action items
- Number of open SAST alerts (by severity)
- Files affected (grouped)
- Brief overview of feedback themes (e.g., "3 style issues, 2 logic concerns, 4
  SAST warnings")

If zero items across all categories, inform the user and stop.

### Step 4: Triage All Feedback

Batch-evaluate all feedback (threads + standalone comments + SAST alerts) using
the suggestion-critic task:

```
task(
  subagent_type="suggestion-critic",
  prompt="""Evaluate all PR feedback for triage.

PR: PR_NUMBER on REPO
Changed files: CHANGED_FILES (from git diff --name-only origin/DEFAULT_BRANCH...HEAD)

Review Threads:
UNRESOLVED_THREADS_JSON

Standalone Review Comments:
REVIEW_COMMENTS_JSON

Code Scanning Alerts:
SAST_ALERTS_JSON

For each review thread/comment, categorize as:
1. **VALID** - Correct feedback, should be fixed. Include suggested fix approach.
2. **INVALID** - Incorrect, doesn't apply, or would introduce bugs. Include explanation.
3. **OUTDATED** - Code already changed or issue already addressed. Include explanation.

For each SAST alert, categorize as:
1. **ACTIONABLE** - Real issue that should be fixed.
2. **FALSE_POSITIVE** - Alert is incorrect or doesn't apply.
3. **WONT_FIX** - Acceptable risk (test code, dev-only, etc.)

Return: item ID, category, reasoning.
Final response under 3000 characters. List outcomes, not process.""",
  description="Triage all PR feedback"
)
```

### Step 5: Process Fixes by File

Group all actionable items (VALID threads, ACTIONABLE SAST alerts) by file path.
Process files in alphabetical order. Within each file, process from **bottom to
top** (highest line number first) to avoid line number shifts.

For SAST alerts in a file, use the `security-auditor` task:

```
task(
  subagent_type="security-auditor",
  prompt="""Evaluate these CodeQL alerts for `FILE_PATH` and recommend fixes.

Alerts:
ALERT_JSON

Read the file. For each alert return:
- Alert number
- Exact code change needed (old code -> new code)
- Brief explanation

Final response under 2000 characters. List outcomes, not process.""",
  description="Evaluate SAST alerts for FILE_PATH"
)
```

For review threads, read the file and fix the code using Edit tool.

#### Reply Mutation (used for all review threads)

```bash
mutation=$(cat <<'EOF'
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
    comment { id }
  }
}
EOF
)
gh api graphql -f query="$mutation" -f threadId=THREAD_ID -f body="EXPLANATION"
```

For each review thread:

1. **VALID**: Read the file, fix the code, reply explaining what was changed,
   track thread ID for resolution
2. **INVALID**: Reply explaining why the feedback doesn't apply, then resolve
3. **OUTDATED**: Reply noting the outdated context, then resolve

If the critic's verdict seems wrong after reading the actual code, override it
with your own judgment.

### Step 6: Commit and Push

After fixing all issues, use `skill(name="git-master")` to commit with a message
summarizing all fixes (review feedback + SAST).

Then push:

```bash
git push
```

### Step 7: Resolve Threads and Dismiss Alerts

#### Resolve review threads

For each thread that was fixed, replied to, or is outdated:

```bash
mutation=$(cat <<'EOF'
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}
EOF
)
gh api graphql -f query="$mutation" -f threadId=THREAD_ID
```

#### Dismiss SAST alerts

For each alert marked as false positive or won't-fix:

```bash
gh api -X PATCH "repos/OWNER/REPO/code-scanning/alerts/ALERT_NUMBER" \
  -f state=dismissed \
  -f dismissed_reason="false positive" \
  -f dismissed_comment="REASON"
```

Valid `dismissed_reason` values: `"false positive"`, `"won't fix"`,
`"used in tests"`.

### Step 8: Report

Summarize:

- **Fixed** (N): threads/alerts where code was changed (file/line, brief
  description)
- **Dismissed** (M): threads replied to as invalid + SAST alerts dismissed (with
  reason)
- **Outdated** (O): threads where code had already changed
- **Skipped** (S): items requiring discussion or clarification (explain why)

For each category, list file/line reference and brief description of action
taken.
