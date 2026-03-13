---
allowed-tools: Bash(gh:*), Bash(git:*), Read, Edit, Write, Skill, Task
description: Resolve PR review conversations by fixing issues and marking resolved
argument-hint: [PR-URL-or-number]
---

## Context

- Repo: !`gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo "unknown"`
- Default branch: !`gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main"`
- Current branch PR: !`gh pr view --json number,url,headRefName 2>/dev/null || echo "no-pr"`

## Your Task

**First, present a summary to the user** showing:
- PR number and title
- Number of unresolved threads
- Files affected
- Brief overview of the feedback themes (e.g., "3 style issues, 2 logic concerns, 1 documentation request")

Then proceed to resolve the conversations.

### Step 1: Determine the PR

Parse `$ARGUMENTS` to get the PR:
- If URL (contains `github.com`): extract owner/repo and PR number
- If number: use current repo
- If empty: use current branch's PR (from context above)

### Step 2: Fetch Unresolved Threads (with Pagination)

**IMPORTANT**: PRs can have more than 100 review threads. You MUST handle pagination.

**IMPORTANT**: Use heredoc syntax to avoid shell escaping issues with exclamation marks in GraphQL types (String!, Int!, ID!):

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

**Pagination**: If `pageInfo.hasNextPage` is true, fetch the next page by adding `-f cursor=ENDCURSOR`. Repeat until all pages collected.

**Filter client-side**: GitHub's `reviewThreads` doesn't support server-side filtering. Use `jq` to filter:

```bash
| jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .path != null)]'
```

### Step 3: Validate Feedback with Critic

Before processing threads individually, batch-evaluate all feedback using the suggestion-critic Task:

```
Task(
  subagent_type="suggestion-critic",
  prompt="""Evaluate these PR review feedback threads.

PR: PR_NUMBER on REPO
Changed files: CHANGED_FILES (from git diff --name-only origin/DEFAULT_BRANCH...HEAD)

Threads:
UNRESOLVED_THREADS_JSON

For each thread, categorize as:
1. **VALID** - Correct feedback, should be fixed with code changes. Include suggested fix approach.
2. **INVALID** - Incorrect, doesn't apply, or would introduce bugs. Include explanation to reply with.
3. **OUTDATED** - Code already changed, line removed, or issue already addressed. Include explanation.

Return: thread ID, category, reasoning.
Final response under 2000 characters. List outcomes, not process.""",
  description="Evaluating PR feedback"
)
```

### Step 4: Process Threads by Category

Use the critic's categorization to guide processing.

#### Reply Mutation (used for INVALID and OUTDATED threads)

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

#### For each thread:

1. **VALID**: Read the file, fix the code using Edit tool, track thread ID for resolution
2. **INVALID**: Reply explaining why the feedback doesn't apply (use reply mutation above), then resolve
3. **OUTDATED**: Reply noting the outdated context (use reply mutation above), then resolve

If the critic's verdict seems wrong after reading the actual code, override it with your own judgment.

### Step 5: Commit and Push

After fixing all issues, use `Skill(skill="commit")` with a message summarizing the review feedback addressed.

Then push:

```bash
git push
```

### Step 6: Resolve Threads

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

### Step 7: Report

Summarize:
- **Fixed**: Threads where code was changed to address valid feedback
- **Dismissed**: Threads where feedback was invalid/incorrect (with brief reason)
- **Outdated**: Threads where the code had already changed or feedback no longer applies
- **Skipped**: Threads that require discussion or clarification (explain why)

For each category, list file/line reference and brief description of action taken.
