---
name: claude-cli
description: Run another Claude CLI instance via tmux for parallel analysis, deep investigation, or when current context is saturated. Use when you need to offload complex analysis while continuing other work.
---

# Claude CLI via tmux

Run a separate Claude instance for parallel analysis and investigation.

## Quick Reference

| Pattern | Command |
|---------|---------|
| Basic query | `claude --print "prompt"` |
| With model | `claude --print --model opus "prompt"` |
| JSON output | `claude --print --output-format json "prompt"` |
| With context | `claude --print --add-dir . "prompt"` |

## When to Use

- Offload complex analysis while continuing current work
- Deep architectural investigation needing fresh context
- Multi-file analysis requiring dedicated attention
- When current context is too saturated

## When NOT to Use

- Simple questions you can answer directly
- Code review (use codex-cli instead)
- Quick sanity checks

## Standard Workflow

### 1. Create Window

```
window_id = mcp__tmux__tmux_new_window(
    command='claude --print "Your analysis request here"',
    name="claude-analysis"
)
```

### 2. Wait for Completion

```
result = mcp__tmux__tmux_wait_idle(target=window_id, idle_seconds=3, timeout=120)
```

### 3. Handle Timeout

```
if result == "timeout":
    partial = mcp__tmux__tmux_capture(target=window_id, lines=500)
    mcp__tmux__tmux_interrupt(target=window_id)
    # Wait for graceful shutdown
    mcp__tmux__tmux_wait_idle(target=window_id, idle_seconds=2, timeout=10)
```

### 4. Capture Output

```
output = mcp__tmux__tmux_capture(target=window_id, lines=2000)
```

### 5. ALWAYS Cleanup

```
mcp__tmux__tmux_kill(target=window_id)
```

## Examples

### Parallel Architecture Analysis

```
window_id = mcp__tmux__tmux_new_window(
    command='claude --print --model opus "Analyze the architecture of this codebase focusing on: 1) Service boundaries 2) Data flow 3) Potential bottlenecks. Directory: /path/to/project"',
    name="arch-analysis"
)
```

### Deep Security Review

```
window_id = mcp__tmux__tmux_new_window(
    command='claude --print "Review /path/to/auth.py for security vulnerabilities, focusing on authentication flows and input validation"',
    name="security-review"
)
```

### Multi-File Context

For larger context, use shell and heredoc:

```
# Create shell window first
window_id = mcp__tmux__tmux_new_window(command="zsh", name="analysis")
mcp__tmux__tmux_wait_idle(target=window_id, idle_seconds=1, timeout=5)

# Send heredoc command
mcp__tmux__tmux_send(target=window_id, text='''claude --print "$(cat <<'EOF'
Analyze these files together:

$(cat /path/to/file1.py)

---

$(cat /path/to/file2.py)

Focus on their interaction patterns.
EOF
)"''')
```

## Error Handling

| Error | Action |
|-------|--------|
| Timeout | Default 120s. For complex analysis, use up to 300s |
| Rate limit | Wait 30s and retry once |
| Auth errors | Notify user to run `claude login` |
| Any error | Always cleanup - kill window even on errors |

## Tips

1. **Use opus for complex tasks**: `--model opus` for detailed reasoning
2. **Absolute paths**: Provide absolute file paths for context
3. **Be specific**: Clearly state what analysis you need
4. **Monitor progress**: Use `tmux_select` to watch if needed
5. **Cost control**: Use `--max-budget-usd 0.50` for expensive operations
