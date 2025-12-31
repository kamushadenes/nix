# Find git root (closest parent with .git, or current dir)
set git_root (git rev-parse --show-toplevel 2>/dev/null || pwd)
set git_folder (basename "$git_root")

# Get parent of git root (company/org name)
set parent_folder (basename (dirname "$git_root"))

# Normalized versions for session name
set git_folder_norm (echo "$git_folder" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/-$//')
set parent_folder_norm (echo "$parent_folder" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/-$//')

# Title: Claude: Parent/GitFolder
set title "Claude: $parent_folder/$git_folder"

# Set Ghostty window/tab title
printf '\033]0;%s\007' "$title"

if test -n "$TMUX"
  # Already in tmux, just run claude
  claude $argv
else
  # Generate session name: claude-<parent>-<git_folder>-<timestamp>
  set timestamp (date +%s)
  set session_name "claude-$parent_folder_norm-$git_folder_norm-$timestamp"

  # Start tmux and run claude inside (exit tmux when claude exits)
  # Use fish -lic to ensure shell initialization runs (including direnv hooks)
  tmux new-session -s "$session_name" "fish -lic 'claude $argv'"
end
