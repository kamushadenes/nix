---
allowed-tools: Bash(gh:*), Bash(git:*), Read, Edit, Write, Skill
description: Resolve PR review conversations by fixing issues and marking resolved
argument-hint: [PR-URL-or-number]
---

## Context

- Repo: !`gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo "unknown"`
- Current branch PR: !`gh pr view --json number,url,headRefName 2>/dev/null || echo "no-pr"`

## Unresolved Threads

!`gh pr view --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false) | "- **\(.path):\(.line // .startLine // "general")** - \(.comments[0].body | split("\n")[0] | if length > 80 then .[:80] + "..." else . end) (@\(.comments[0].author.login))"' 2>/dev/null || echo "No unresolved threads found"`

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
3. **Critically evaluate the comment**: Before making any changes, assess whether the feedback is actually valid:
   - Is the reviewer's understanding of the code correct?
   - Does the suggested change actually improve the code?
   - Is the feedback based on outdated context or a misreading?
   - Would implementing it introduce bugs or regressions?

4. **If the comment is OUTDATED** (code already changed, line no longer exists, or issue already addressed):
   - Reply to the thread noting it's outdated:
     ```bash
     gh api graphql -f query='
     mutation($threadId: ID!, $body: String!) {
       addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
         comment { id }
       }
     }' -f threadId=THREAD_ID -f body="This feedback appears to be outdated - [explain why: code changed, line removed, etc.]"
     ```
   - Then resolve the thread (Step 5)

5. **If the comment is INVALID** (incorrect understanding, would introduce bugs, or doesn't apply):
   - Reply to the thread explaining why the feedback doesn't apply:
     ```bash
     gh api graphql -f query='
     mutation($threadId: ID!, $body: String!) {
       addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
         comment { id }
       }
     }' -f threadId=THREAD_ID -f body="EXPLANATION"
     ```
   - Then resolve the thread (Step 5)
   - **Do NOT make code changes for invalid feedback**

7. **If the comment is VALID**:
   - Fix the code using Edit tool to address the feedback
   - Track the thread ID for resolution in Step 5

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
- **Fixed**: Threads where code was changed to address valid feedback
- **Dismissed**: Threads where feedback was invalid/incorrect (with brief reason)
- **Outdated**: Threads where the code had already changed or feedback no longer applies
- **Skipped**: Threads that require discussion or clarification (explain why)

For each category, list:
- File and line reference
- Brief description of action taken or reason for dismissal
