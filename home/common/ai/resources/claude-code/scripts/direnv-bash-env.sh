#!/usr/bin/env bash
# BASH_ENV script for Claude Code sessions
# Evaluates direnv for the current working directory so that
# non-interactive Bash tool invocations pick up .envrc variables.
# See: https://github.com/anthropics/claude-code/issues/2110

# Prevent recursive sourcing
if [ -n "$__DIRENV_BASH_ENV_SOURCED" ]; then return; fi
export __DIRENV_BASH_ENV_SOURCED=1

if ! command -v direnv >/dev/null 2>&1; then
  return
fi

# Auto-allow .envrc in git worktrees when the main tree's .envrc is allowed.
# This handles worktrees created by `git worktree add`, worktrunk, or
# Claude Code's isolation: "worktree" agent mode.
_direnv_auto_allow_worktree() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -f "$toplevel/.envrc" ] || return 0

  # Check if we're in a worktree (git-common-dir differs from git-dir)
  local git_common_dir git_dir
  git_common_dir="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)" || return 0
  git_dir="$(cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd)" || return 0
  [ "$git_common_dir" != "$git_dir" ] || return 0

  # Main worktree root is parent of .git common dir
  local main_toplevel
  main_toplevel="$(dirname "$git_common_dir")"
  [ -f "$main_toplevel/.envrc" ] || return 0

  # Only auto-allow if .envrc content matches (prevents allowing modified files)
  if cmp -s "$toplevel/.envrc" "$main_toplevel/.envrc"; then
    direnv allow "$toplevel" 2>/dev/null || true
  fi
}

_direnv_auto_allow_worktree
eval "$(DIRENV_LOG_FORMAT= direnv export bash)"
