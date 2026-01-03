---
name: parallel-processing
description: Run multiple tasks in parallel using tmux windows
---

# Parallel Processing

Use tmux for background tasks and parallel work.

## Pattern: Background Task

```python
# Start background task
window_id = tmux_new_window(command="npm run dev", name="dev-server")

# Continue working...

# Check later
output = tmux_capture(target=window_id, lines=50)

# Clean up
tmux_kill(target=window_id)
```

## Pattern: With Notification

```python
window_id = tmux_new_window(command="npm run build", name="build")
status = tmux_wait_idle(target=window_id, timeout=300)
notify(title="Build Complete", message=f"Status: {status}")
```

## Pattern: Multiple Parallel

```python
test_win = tmux_new_window(command="npm test", name="tests")
lint_win = tmux_new_window(command="npm run lint", name="lint")
build_win = tmux_new_window(command="npm run build", name="build")

for w in [test_win, lint_win, build_win]:
    tmux_wait_idle(target=w, timeout=120)
```
