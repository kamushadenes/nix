---
name: automating-tmux-windows
description: Automates terminal sessions in tmux windows using MCP tools. Use when launching background processes, monitoring builds/servers, sending commands to debuggers (pdb/gdb), interacting with CLI prompts, using interactive commands or commands that require sudo, or orchestrating parallel tasks across multiple terminal sessions.
triggers: tmux, terminal automation, background process, interactive commands, sudo, debugger, pdb, gdb, long-running process, server monitoring
---

# Automating tmux Windows

Control tmux windows programmatically via orchestrator MCP.

## Quick Reference

| Tool | Purpose |
|------|---------|
| `tmux_new_window` | Create window with command |
| `tmux_send` | Send text/keys |
| `tmux_capture` | Get output |
| `tmux_wait_idle` | Wait for idle |
| `tmux_kill` | Close window |
| `tmux_interrupt` | Send Ctrl+C |
| `tmux_run_and_read` | Run command, return file output |

## Standard Workflow

```python
# 1. Create window - SAVE THE RETURNED ID
window_id = mcp__orchestrator__tmux_new_window(command="npm run build", name="build")

# 2. Wait for completion
mcp__orchestrator__tmux_wait_idle(target=window_id, idle_seconds=2.0)

# 3. Get output
output = mcp__orchestrator__tmux_capture(target=window_id, lines=50)

# 4. Cleanup
mcp__orchestrator__tmux_kill(target=window_id)
```

## Interactive Commands

```python
window_id = mcp__orchestrator__tmux_new_window(command="sudo apt update", name="sudo")
mcp__orchestrator__tmux_wait_idle(target=window_id, idle_seconds=1, timeout=10)
mcp__orchestrator__tmux_send(target=window_id, text="password")
```

## File-Based Output

```python
# Use __OUTPUT_FILE__ placeholder for tools with -o flags
result = mcp__orchestrator__tmux_run_and_read(
    command="my-tool --output __OUTPUT_FILE__",
    name="task", timeout=300
)
```

## References

- **Tool parameters**: See `references/tool-params.md`
