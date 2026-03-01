#!/usr/bin/env bash
# Auto-format and lint Python files after Claude edits them
# Outputs JSON block only if there are unfixable lint issues

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Load devbox environment if available (provides project-pinned tools like ruff)
if [[ -f "devbox.json" ]] && command -v devbox &>/dev/null; then
    eval "$(devbox shellenv 2>/dev/null)" 2>/dev/null || true
fi

# Extract file path from tool input
file_path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
[[ "$file_path" != *.py ]] && exit 0

# Step 1: Format with ruff
if command -v ruff &>/dev/null; then
    ruff format "$file_path" 2>/dev/null

    # Step 2: Auto-fix lint issues
    ruff check --fix "$file_path" 2>/dev/null

    # Step 3: Check for remaining (unfixable) issues
    lint_output=$(ruff check --output-format json "$file_path" 2>/dev/null)

    # Only report if there are unfixable issues
    if [[ -n "$lint_output" && "$lint_output" != "[]" ]]; then
        unfixable=$(echo "$lint_output" | python3 -c "
import json, sys
try:
    issues = json.load(sys.stdin)
    if issues:
        lines = []
        for i in issues:
            code = i.get('code', 'unknown')
            msg = i.get('message', '')
            loc = i.get('location', {})
            line = loc.get('row', '?')
            lines.append(f'  Line {line}: [{code}] {msg}')
        report = '\n'.join(lines)
        print(json.dumps({'decision': 'block', 'reason': f'Python lint issues (cannot auto-fix):\n{report}'}))
except:
    pass
" 2>/dev/null)

        if [[ -n "$unfixable" ]]; then
            echo "$unfixable"
        fi
    fi
fi

exit 0
