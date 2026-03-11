#!/usr/bin/env bash
# Run project linter on Stop, but only if lintable files changed since last run.
#
# Uses a fingerprint cache (hash of changed lintable file paths + HEAD) to skip
# redundant lint runs across consecutive stops.

set -euo pipefail

# Read hook input (contains session_id)
HOOK_INPUT=$(cat)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)

if [[ -z "$SESSION_ID" ]]; then
	exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

# Lintable file extensions
LINT_EXTS='go|py|ts|tsx|js|jsx|nix|sh|bash|yml|yaml|json|toml|tf|hcl|sql|rs|rb|java|kt|swift|c|cpp|h'

# --- Early exits ---

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
	exit 0
fi

if ! command -v just &>/dev/null; then
	exit 0
fi

if ! just --list 2>/dev/null | grep -qE '^\s+lint(-fix)?(\s|$)'; then
	exit 0
fi

# --- Check for changed lintable files ---

# Collect all changed files: staged, unstaged, and untracked
changed=$(
	{
		git diff --name-only 2>/dev/null
		git diff --cached --name-only 2>/dev/null
		git ls-files --others --exclude-standard 2>/dev/null
	} | sort -u
)

# Filter to lintable extensions
lintable=$(echo "$changed" | grep -iE "\.(${LINT_EXTS})$" || true)

if [[ -z "$lintable" ]]; then
	exit 0
fi

# --- Fingerprint cache ---

cache_file="/tmp/claude-lint-cache-${SESSION_ID}"
head_sha=$(git rev-parse HEAD 2>/dev/null || echo "none")
fingerprint=$(echo "${head_sha}:${lintable}" | shasum -a 256 | cut -c1-40)

if [[ -f "$cache_file" ]] && [[ "$(cat "$cache_file" 2>/dev/null)" == "$fingerprint" ]]; then
	exit 0
fi

# --- Load devbox if available ---

if [[ -f "devbox.json" ]] && command -v devbox &>/dev/null; then
	eval "$(devbox shellenv 2>/dev/null)" 2>/dev/null || true
fi

# --- Run lint ---

if just --list 2>/dev/null | grep -qE '^\s+lint-fix(\s|$)'; then
	lint_cmd="lint-fix"
else
	lint_cmd="lint"
fi

output=$(just $lint_cmd 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
	# Lint failed - don't update cache so it reruns next time
	python3 -c "
import json, sys
output = sys.stdin.read()
print(json.dumps({'decision': 'block', 'reason': 'Lint failed:\\n' + output}))
" <<<"$output"
	exit 0
fi

# Lint passed - update cache
echo "$fingerprint" >"$cache_file"
exit 0
