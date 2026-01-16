#!/usr/bin/env bash
# Link PR to Task Hook - Auto-links PRs to GitHub issues and task-master
#
# After `gh pr create` runs, this hook:
# 1. Gets the PR URL from the current branch
# 2. Checks if the branch name contains an issue reference (feat/<N>-*)
# 3. Comments on the GitHub issue with the PR link
# 4. Updates the task-master task if one exists

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Extract command from tool input
command=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty')
[[ -z "$command" ]] && exit 0

# Only run for gh pr create commands
[[ "$command" != *"gh pr create"* ]] && exit 0

# Verify we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Get current branch name
branch=$(git branch --show-current 2>/dev/null)
[[ -z "$branch" ]] && exit 0

# Get the PR URL for the current branch
pr_url=$(gh pr view --json url -q .url 2>/dev/null || echo "")
[[ -z "$pr_url" ]] && exit 0

# Extract issue number from branch name (feat/123-description or feat/GH-123-description)
issue_num=""
if [[ "$branch" =~ ^feat/([0-9]+)- ]]; then
  issue_num="${BASH_REMATCH[1]}"
elif [[ "$branch" =~ ^feat/GH-([0-9]+)- ]]; then
  issue_num="${BASH_REMATCH[1]}"
elif [[ "$branch" =~ -([0-9]+)$ ]]; then
  issue_num="${BASH_REMATCH[1]}"
fi

# If we found an issue number, comment on it
if [[ -n "$issue_num" ]]; then
  # Get repo info
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")

  if [[ -n "$repo" ]]; then
    # Add comment to the issue (if it exists)
    gh issue comment "$issue_num" --body "PR created: $pr_url" 2>/dev/null || true

    # Output for Claude to see
    echo "Linked PR $pr_url to issue #$issue_num"
  fi
fi

# Update task-master task if it exists with [GH:#N] prefix
if [[ -n "$issue_num" && -d ".taskmaster" ]]; then
  # Check if a task with this issue exists and update its description
  # This is a best-effort operation
  if command -v npx &>/dev/null; then
    npx -y task-master-ai update --id="GH:#$issue_num" --description="PR: $pr_url" 2>/dev/null || true
  fi
fi

exit 0
