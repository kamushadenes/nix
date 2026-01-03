#!/bin/bash
# Auto-format Python files after Claude edits them
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
file_path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
[[ "$file_path" != *.py ]] && exit 0
command -v ruff &>/dev/null && ruff format "$file_path" 2>/dev/null
exit 0
