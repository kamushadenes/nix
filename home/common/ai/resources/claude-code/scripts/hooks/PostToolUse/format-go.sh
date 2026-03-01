#!/usr/bin/env bash
# Auto-format Go files after Claude edits them
# Uses goimports for import organization + formatting

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Load devbox environment if available (provides project-pinned tools like goimports)
if [[ -f "devbox.json" ]] && command -v devbox &>/dev/null; then
    eval "$(devbox shellenv 2>/dev/null)" 2>/dev/null || true
fi

# Extract file path from tool input
file_path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
[[ "$file_path" != *.go ]] && exit 0

# Prefer goimports (handles imports + formatting), fallback to gofmt
if command -v goimports &>/dev/null; then
    goimports -w "$file_path" 2>/dev/null
elif command -v gofmt &>/dev/null; then
    gofmt -w "$file_path" 2>/dev/null
fi

exit 0
