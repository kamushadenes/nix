# Shell Non-Interactive Strategy (Global)

The shell environment is strictly **non-interactive** — no TTY/PTY. Any command
that waits for user input will hang indefinitely.

## Core Mandates

1. **Assume `CI=true`**: Act as if running in a headless CI/CD pipeline.
2. **No Editors/Pagers**: `vim`, `nano`, `less`, `more`, `man` are BANNED.
3. **Force & Yes**: Always preemptively supply `-y`, `--yes`, `--force`,
   `--non-interactive` flags.
4. **Use Tools**: Prefer `Read`/`Write`/`Edit` tools over shell file
   manipulation.
5. **No Interactive Modes**: Never use `-i` or `-p` flags that require user
   input.

## Banned Commands (Will Hang)

- **Editors**: `vim`, `vi`, `nano`, `emacs`, `pico`, `ed`
- **Pagers**: `less`, `more`, `most`, `pg`
- **Manual pages**: `man`
- **Interactive git**: `git add -p`, `git rebase -i`, `git commit` (without -m)
- **REPLs**: `python`, `node`, `irb`, `ghci` (without script/command)
- **Interactive shells**: `bash -i`, `zsh -i`

When a command has no non-interactive flag, use `yes |`, heredoc input, or
`timeout` as a wrapper.
