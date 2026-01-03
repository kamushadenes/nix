---
name: feedback-loop
description: Update CLAUDE.md or rules when patterns of errors emerge
---

# Feedback Loop

When Claude makes the same mistake repeatedly, capture the learning.

## When to Use

- Same error type 2+ times
- Project convention violated
- Important pattern discovered

## Process

1. **Identify Pattern** - What mistake? What's correct?
2. **Choose Location**
   - Project-specific: Add to project's `CLAUDE.md`
   - Global: Add to `~/.claude/rules/` via Nix
3. **Write the Rule**
4. **Verify** - Clear and actionable?

## Example

After repeatedly missing `--impure` flag:

```markdown
## Nix Flakes

- Always use `--impure` flag (required for private submodule)
- Use `rebuild` alias instead of raw commands
```
