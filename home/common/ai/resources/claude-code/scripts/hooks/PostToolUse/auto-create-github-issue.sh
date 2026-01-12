#!/usr/bin/env bash
# PostToolUse hook for mcp__task-master-ai__add_task
# Auto-creates GitHub issue and links to task
#
# Runs after add_task completes. Finds the most recently added task
# without a [GH:#N] prefix, creates a GitHub issue, and updates the task title.

set -euo pipefail

# Check if GitHub repo
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ ! "$remote_url" =~ github\.com ]]; then
    exit 0  # Not a GitHub repo, skip
fi

# Extract owner/repo from SSH or HTTPS URL
if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
else
    exit 0
fi

# Find task file
task_file=".taskmaster/tasks.json"
[[ -f "$task_file" ]] || exit 0

# Use jq to find tasks without GH prefix, get the one with highest ID (most recent)
# Output format: id|title|description
task=$(jq -r '
    .tasks
    | map(select(.title | test("^\\[GH:#") | not))
    | sort_by(.id | tonumber)
    | last
    | "\(.id)|\(.title)|\(.description // "")"
' "$task_file" 2>/dev/null || echo "")

# Check if we got a valid task
if [[ -z "$task" ]] || [[ "$task" == "null|null|" ]] || [[ "$task" == "||" ]]; then
    exit 0
fi

id=$(echo "$task" | cut -d'|' -f1)
title=$(echo "$task" | cut -d'|' -f2)
desc=$(echo "$task" | cut -d'|' -f3-)

# Validate we have required fields
[[ -z "$id" ]] && exit 0
[[ -z "$title" ]] && exit 0

# Build issue body
body="## Task

${desc:-No description provided}

---
_Tracked in task-master. ID: ${id}_"

# Create GitHub issue
issue_url=$(gh issue create \
    --repo "${owner}/${repo}" \
    --title "$title" \
    --body "$body" \
    --label "task-master" 2>/dev/null || echo "")

# Validate we got an issue URL
[[ -z "$issue_url" ]] && exit 0

# Extract issue number from URL (e.g., https://github.com/owner/repo/issues/123)
issue_num=$(echo "$issue_url" | grep -oE '[0-9]+$' || echo "")
[[ -z "$issue_num" ]] && exit 0

# Update task title with [GH:#N] prefix
npx task-master-ai update-task --id="$id" --title="[GH:#${issue_num}] ${title}" 2>/dev/null || true

exit 0
