---
allowed-tools: Bash(gh:*), Bash(git:*), Read, Edit, Write, Skill
description: Resolve PR review conversations by fixing issues and marking resolved
argument-hint: [PR-URL-or-number]
---

## Context

- Repo: !`gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo "unknown"`
- Current branch PR: !`gh pr view --json number,url,headRefName 2>/dev/null || echo "no-pr"`

## Your Task

Resolve unresolved PR review conversations by fixing the code issues and marking them as resolved.

### Step 1: Determine the PR

Parse `$ARGUMENTS` to get the PR:
- If URL (contains `github.com`): extract owner/repo and PR number
- If number: use current repo
- If empty: use current branch's PR (from context above)

### Step 2: Fetch Unresolved Threads

```bash
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
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
}' -f owner=OWNER -f repo=REPO -F pr=NUMBER
```

Filter for `isResolved == false` threads that have a `path` (file-level comments).

### Step 3: For Each Unresolved Thread

1. **Show the feedback**: Display the file, line, and reviewer comment(s)
2. **Read the file**: Use Read tool to understand the context around the mentioned line
3. **Analyze the issue**: Determine what change the reviewer is requesting
4. **Fix the code**: Use Edit tool to address the feedback
5. **Track the thread ID**: Save for resolution in Step 5

### Step 4: Commit and Push

After fixing all issues:

```bash
# Use the commit skill for proper commit workflow
```

Use `Skill(skill="commit")` with a message summarizing the review feedback addressed.

Then push:

```bash
git push
```

### Step 5: Resolve Threads

For each thread ID that was fixed:

```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}' -f threadId=THREAD_ID
```

### Step 6: Report

Summarize:
- Number of threads resolved
- Files modified
- Brief description of changes made

If any threads could not be resolved (e.g., unclear feedback, requires discussion), list them and explain why.
