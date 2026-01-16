#!/usr/bin/env bash
# Auto-format TypeScript files after Claude edits them
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
file_path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
[[ "$file_path" != *.ts && "$file_path" != *.tsx ]] && exit 0
command -v prettier &>/dev/null && prettier --write "$file_path" 2>/dev/null
exit 0
