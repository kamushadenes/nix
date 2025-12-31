---
name: automating-tmux-windows
description: Automates terminal sessions in tmux windows using MCP tools. Use when launching background processes, monitoring builds/servers, sending commands to debuggers (pdb/gdb), interacting with CLI prompts, using interactive commands or commands that require sudo, or orchestrating parallel tasks across multiple terminal sessions.
---

# Automating tmux Windows

Control tmux windows programmatically: create windows, send commands, capture output, and manage processes. Each window gets full screen space for easier output tracking.

## Quick Reference

| Tool                         | Purpose             |
| ---------------------------- | ------------------- |
| `mcp__tmux__tmux_new_window` | Create new window   |
| `mcp__tmux__tmux_send`       | Send text/keys      |
| `mcp__tmux__tmux_capture`    | Get window output   |
| `mcp__tmux__tmux_list`       | List windows (JSON) |
| `mcp__tmux__tmux_kill`       | Close window        |
| `mcp__tmux__tmux_interrupt`  | Send Ctrl+C         |
| `mcp__tmux__tmux_wait_idle`  | Wait for idle       |
| `mcp__tmux__tmux_select`     | Switch to window    |

## Critical: Always Start with a Shell

Launch a shell first, then run commands. Direct command execution loses output on exit:

```
# Correct workflow - save the window ID
window_id = mcp__tmux__tmux_new_window(command="zsh", name="build")  # Returns "@3"
mcp__tmux__tmux_send(target=window_id, text="python script.py")

# Wrong - output lost if script exits/errors
mcp__tmux__tmux_new_window(command="python script.py")
```

## Window Identifiers

**Always use the window ID returned by `tmux_new_window`** (e.g., `"@3"`). These IDs:

- Never change when other windows are created or killed
- Persist until the window itself is destroyed
- Are the only reliable way to reference windows across operations

Window names are visible in the tmux status bar for easy identification.

## Standard Workflow

```
# 1. Create window with shell - SAVE THE RETURNED ID
window_id = mcp__tmux__tmux_new_window(command="zsh", name="build")  # Returns "@3"

# 2. Run command using the window ID
mcp__tmux__tmux_send(target=window_id, text="npm run build")

# 3. Wait for completion
mcp__tmux__tmux_wait_idle(target=window_id, idle_seconds=2.0)  # Returns "idle" or "timeout"

# 4. Get output
output = mcp__tmux__tmux_capture(target=window_id, lines=50)

# 5. Optionally switch to window to view it
mcp__tmux__tmux_select(target=window_id)

# 6. Cleanup
mcp__tmux__tmux_kill(target=window_id)
```

## Parallel Windows

Create multiple windows for parallel tasks:

```
# Create named windows for different tasks
logs_window = mcp__tmux__tmux_new_window(command="zsh", name="logs")
work_window = mcp__tmux__tmux_new_window(command="zsh", name="work")

# Run commands in parallel
mcp__tmux__tmux_send(target=logs_window, text="tail -f /var/log/app.log")
mcp__tmux__tmux_send(target=work_window, text="cd ~/project && make")

# Capture from both
logs = mcp__tmux__tmux_capture(target=logs_window, lines=100)
output = mcp__tmux__tmux_capture(target=work_window, lines=50)
```

## Window Navigation

- Use `tmux_select` to switch to a window programmatically
- User can navigate with Ctrl+b n (next) / Ctrl+b p (previous)
- Window names appear in tmux status bar

## Safety

- Cannot kill own window (server prevents this)
- Use `tmux_interrupt` to stop runaway processes
- Check `is_claude` field in `tmux_list` to identify your window
- **Always store and reuse the window ID from `tmux_new_window`**
