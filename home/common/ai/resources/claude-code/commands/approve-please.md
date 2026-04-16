---
allowed-tools: Bash(gh:*), mcp__claude_ai_Slack__slack_send_message
description: Send PR approval request to #approve-please Slack channel
---

## Context

- Current branch PR: !`gh pr view --json number,url,title,headRefName 2>/dev/null || echo "no-pr"`

## Your Task

Send a PR approval request to the **#approve-please** Slack channel.

### Steps

1. **Check PR exists.** If the context above shows "no-pr", tell the user there's no open PR for this branch and stop.
2. **Send the Slack message.** Use `mcp__claude_ai_Slack__slack_send_message` with:
   - `channel_id`: `C0ATG7LC1MJ`
   - `message`: `:please-approve: <PR_URL>`
3. **Confirm** to the user with the PR title and link.
