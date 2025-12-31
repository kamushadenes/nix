# List tmux sessions and attach to selected one via new session
# Uses fzf for interactive selection

set sessions (tmux list-sessions -F "#{session_name}: #{session_windows} windows (created #{session_created_string})" 2>/dev/null)

if test -z "$sessions"
    echo "No tmux sessions found"
    return 1
end

set selected (echo $sessions | fzf --height=40% --reverse --prompt="Select session: ")

if test -z "$selected"
    echo "No session selected"
    return 1
end

# Extract session name (everything before the first colon)
set session_name (echo $selected | cut -d: -f1)

# Create a new session attached to the selected one
tmux new-session -t "$session_name"
