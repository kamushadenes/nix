#!/usr/bin/env bash
# Auto-format Nix files after Claude edits them
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
file_path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
[[ "$file_path" != *.nix ]] && exit 0
command -v nixfmt &>/dev/null && nixfmt "$file_path" 2>/dev/null
exit 0
