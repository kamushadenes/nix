# tmux Tool Parameters

## tmux_new_window

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `command` | string | "zsh" | Command to run (auto shell-wrapped) |
| `name` | string | "" | Window name for status bar |

**Always use returned window ID** (e.g., `"@3"`) - never changes, reliable across operations.

## tmux_run_and_read

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `command` | string | required | Command with `__OUTPUT_FILE__` placeholder |
| `name` | string | "" | Window name |
| `timeout` | int | 300 | Max seconds |

- Does NOT spawn shell wrapper
- Waits for window close, not idle
- Returns file contents, auto-cleans up

## tmux_wait_idle

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `target` | string | required | Window ID (e.g., "@3") |
| `idle_seconds` | float | 2.0 | No-change threshold |
| `timeout` | int | 60 | Max wait |

## tmux_capture

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `target` | string | required | Window ID |
| `lines` | int | 100 | Lines to capture (max: 10000) |

## Safety Notes

- Cannot kill own window
- Use `tmux_interrupt` for runaway processes
- Check `is_claude` in `tmux_list` to identify your window
