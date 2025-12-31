# Find git root (closest parent with .git, or current dir)
git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
git_folder=$(basename "$git_root")

# Get parent of git root (company/org name)
parent_folder=$(basename "$(dirname "$git_root")")

# Normalized versions for session name
git_folder_norm=$(echo "$git_folder" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/-$//')
parent_folder_norm=$(echo "$parent_folder" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/-$//')

# Title: Claude: Parent/GitFolder
title="Claude: $parent_folder/$git_folder"

# Set Ghostty window/tab title
printf '\033]0;%s\007' "$title"

if test -n "$TMUX"; then
  # Already in tmux, just run claude
  claude "$@"
else
  # Generate session name: claude-<parent>-<git_folder>-<timestamp>
  timestamp=$(date +%s)
  session_name="claude-$parent_folder_norm-$git_folder_norm-$timestamp"

  # Start tmux and run claude inside (exit tmux when claude exits)
  # Use bash -lic to ensure shell initialization runs (including direnv hooks)
  tmux new-session -s "$session_name" "bash -lic 'claude $*'"
fi
