#!/usr/bin/env bash
# Stop hook: format all modified files at session end.
# Replaces per-file PostToolUse hooks since Codex's PostToolUse only fires for Bash.

set -euo pipefail

# Read hook JSON from stdin to get cwd
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
[[ -z "$cwd" || ! -d "$cwd" ]] && exit 0

cd "$cwd" || exit 0

# Load devbox environment if available (provides project-pinned tools)
if [[ -f "devbox.json" ]] && command -v devbox &>/dev/null; then
    eval "$(devbox shellenv 2>/dev/null)" 2>/dev/null || true
fi

# Bail if not a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Collect changed files (staged + unstaged + untracked), deduplicated
mapfile -t files < <(
    {
        git diff --name-only 2>/dev/null
        git diff --name-only --cached 2>/dev/null
        git ls-files --others --exclude-standard 2>/dev/null
    } | sort -u
)

[[ ${#files[@]} -eq 0 ]] && exit 0

for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue

    case "$file" in
        *.py)
            if command -v ruff &>/dev/null; then
                ruff format "$file" 2>/dev/null || true
                ruff check --fix "$file" 2>/dev/null || true
            fi
            ;;
        *.ts|*.tsx|*.js|*.jsx)
            if command -v prettier &>/dev/null; then
                prettier --write "$file" 2>/dev/null || true
            fi
            ;;
        *.nix)
            if command -v nixfmt &>/dev/null; then
                nixfmt "$file" 2>/dev/null || true
            fi
            ;;
        *.go)
            if command -v goimports &>/dev/null; then
                goimports -w "$file" 2>/dev/null || true
            fi
            ;;
        *.md)
            if command -v prettier &>/dev/null; then
                prettier --write --prose-wrap always "$file" 2>/dev/null || true
            fi
            ;;
    esac
done

exit 0
