Run a code review on current changes using Codex.

## Steps

1. First, check if there are changes to review by running `git status --short`

2. If there are no changes, inform the user that there's nothing to review and stop

3. If there are changes, run Codex review via tmux:

```
window_id = mcp__tmux__tmux_new_window(
    command="codex review --uncommitted",
    name="code-review"
)
mcp__tmux__tmux_wait_idle(target=window_id, idle_seconds=5, timeout=180)
output = mcp__tmux__tmux_capture(target=window_id, lines=1000)
mcp__tmux__tmux_kill(target=window_id)
```

4. Parse and present the findings organized as:
   - **Critical Issues** - Must fix before committing
   - **Suggestions** - Improvements to consider
   - **Positive Notes** - What's done well

5. Offer to help address any issues found
