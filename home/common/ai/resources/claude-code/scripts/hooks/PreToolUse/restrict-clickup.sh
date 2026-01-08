#!/bin/bash
# Restrict workspace-scoped ClickUp MCP to appropriate project directories
# Usage: restrict-clickup.sh <workspace>
# Exit codes: 0 = allow, 2 = block

WORKSPACE="${1:-}"

# Read hook input from stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')

# If no cwd provided, allow (shouldn't happen, but fail open for safety)
[[ -z "$cwd" ]] && exit 0

# Define allowed paths per workspace
# Add new workspaces here as needed
case "$WORKSPACE" in
  iniciador)
    ALLOWED_PATHS=(
      "$HOME/Dropbox/Projects/Iniciador"
      "$HOME/.local/share/git/workspaces/iniciador"
    )
    ;;
  altinity)
    ALLOWED_PATHS=(
      "$HOME/Dropbox/Projects/Altinity"
      "$HOME/.local/share/git/workspaces/altinity"
    )
    ;;
  *)
    # Unknown workspace - block by default
    echo "Unknown workspace: $WORKSPACE" >&2
    exit 2
    ;;
esac

# Check if cwd is within any allowed path
for allowed in "${ALLOWED_PATHS[@]}"; do
  if [[ "$cwd" == "$allowed"* ]]; then
    exit 0
  fi
done

# Block access - not in allowed directory
echo "ClickUp MCP ($WORKSPACE-clickup) is restricted to $WORKSPACE projects:" >&2
for allowed in "${ALLOWED_PATHS[@]}"; do
  echo "  - ${allowed/#$HOME/\~}" >&2
done
exit 2
