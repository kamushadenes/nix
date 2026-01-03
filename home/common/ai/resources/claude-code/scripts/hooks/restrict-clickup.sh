#!/bin/bash
# Restrict ClickUp MCP to Iniciador project directories only
# Exit codes: 0 = allow, 2 = block

# Read hook input from stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')

# If no cwd provided, allow (shouldn't happen, but fail open for safety)
[[ -z "$cwd" ]] && exit 0

# Allowed paths (Iniciador projects only)
ALLOWED_PATHS=(
  "$HOME/Dropbox/Projects/Iniciador"
  "$HOME/.local/share/git/workspaces/iniciador"
)

# Check if cwd is within any allowed path
for allowed in "${ALLOWED_PATHS[@]}"; do
  # Expand ~ to $HOME
  expanded="${allowed/#\~/$HOME}"
  if [[ "$cwd" == "$expanded"* ]]; then
    exit 0
  fi
done

# Block access - not in allowed directory
echo "ClickUp MCP is restricted to Iniciador projects:" >&2
echo "  - ~/Dropbox/Projects/Iniciador" >&2
echo "  - ~/.local/share/git/workspaces/iniciador" >&2
exit 2
