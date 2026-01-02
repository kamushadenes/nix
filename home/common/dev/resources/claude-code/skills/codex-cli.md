---
name: codex-cli
description: Run Codex CLI for code review and second opinions via tmux. Primary use is code review before commits/PRs. Also supports general queries for a non-Claude perspective.
---

# Codex CLI via tmux

Run OpenAI Codex for code review and second opinions.

## Quick Reference

| Pattern | Command |
|---------|---------|
| Review uncommitted | `codex review --uncommitted` |
| Review vs branch | `codex review --base main` |
| Review commit | `codex review --commit <sha>` |
| Custom focus | `codex review "Focus on security"` |
| General query | `codex exec "prompt"` |

## When to Use

### Code Review (Primary)

- Before creating a commit
- Before opening a PR
- Reviewing specific commits
- Security-focused review

### Second Opinion (Secondary)

- Want a non-Claude perspective
- Quick implementation validation
- Alternative approach suggestions

## When NOT to Use

- Complex architectural analysis (use claude-cli)
- When you need detailed reasoning chains
- File modifications (always use read-only mode)

## Code Review Workflow

### 1. Create Window

```
window_id = mcp__tmux__tmux_new_window(
    command="codex review --uncommitted",
    name="codex-review"
)
```

### 2. Wait (reviews can be slow)

```
result = mcp__tmux__tmux_wait_idle(target=window_id, idle_seconds=5, timeout=180)
```

### 3. Capture Results

```
output = mcp__tmux__tmux_capture(target=window_id, lines=1000)
```

### 4. Cleanup

```
mcp__tmux__tmux_kill(target=window_id)
```

## Review Modes

### Uncommitted Changes

```
codex review --uncommitted
```

Reviews all staged, unstaged, and untracked changes.

### Compare to Branch

```
codex review --base main
codex review --base origin/develop
```

Reviews changes since branching from base.

### Specific Commit

```
codex review --commit abc123
```

### Custom Focus

```
codex review --uncommitted "Focus on error handling"
codex review --base main "Check for security issues"
```

## Second Opinion (codex exec)

For general questions beyond code review:

```
window_id = mcp__tmux__tmux_new_window(
    command='codex exec "Is this approach to caching reasonable: [description]"',
    name="codex-opinion"
)
mcp__tmux__tmux_wait_idle(target=window_id, idle_seconds=5, timeout=120)
output = mcp__tmux__tmux_capture(target=window_id, lines=500)
mcp__tmux__tmux_kill(target=window_id)
```

## Error Handling

| Error | Action |
|-------|--------|
| Timeout | Code reviews can take 2-3 minutes for large diffs |
| "not a git repository" | Must run in git repo directory |
| "no changes" | Nothing to review - inform user |
| Rate limits | Wait 30s and retry once |

## Tips

1. **Review incrementally**: Smaller changes get better feedback
2. **Add focus prompts**: Specify concerns like "Focus on security"
3. **Use longer timeouts**: 180s for large diffs
4. **Git context**: Codex works best with git repositories
5. **Always cleanup**: Kill window even on errors
