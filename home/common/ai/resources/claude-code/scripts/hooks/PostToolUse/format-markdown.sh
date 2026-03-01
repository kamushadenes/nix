#!/usr/bin/env bash
# Auto-format and lint Markdown files after Claude edits them
# Outputs JSON block only if there are unfixable lint issues

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Load devbox environment if available (provides project-pinned tools like prettier, markdownlint)
if [[ -f "devbox.json" ]] && command -v devbox &>/dev/null; then
    eval "$(devbox shellenv 2>/dev/null)" 2>/dev/null || true
fi

# Extract file path from tool input
file_path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
[[ "$file_path" != *.md ]] && exit 0

# Config path (installed by home-manager)
config_path="$HOME/.claude/config/markdownlint.jsonc"

# Step 1: Format with prettier (tables, whitespace, structure)
if command -v prettier &>/dev/null; then
    prettier --write "$file_path" 2>/dev/null
fi

# Step 2: Auto-fix with markdownlint
if command -v markdownlint &>/dev/null && [[ -f "$config_path" ]]; then
    markdownlint --fix --config "$config_path" "$file_path" 2>/dev/null

    # Step 3: Check for remaining (unfixable) issues
    lint_output=$(markdownlint --json --config "$config_path" "$file_path" 2>/dev/null)

    # Only report if there are unfixable issues
    if [[ -n "$lint_output" && "$lint_output" != "[]" ]]; then
        # Filter to only unfixable issues (those without fixInfo)
        unfixable=$(echo "$lint_output" | python3 -c "
import json, sys
try:
    issues = json.load(sys.stdin)
    unfixable = [i for i in issues if not i.get('fixInfo')]
    if unfixable:
        lines = []
        for i in unfixable:
            rule = i['ruleNames'][0]
            desc = i['ruleDescription']
            line = i['lineNumber']
            ctx = i.get('errorContext', '')
            lines.append(f'  Line {line}: [{rule}] {desc}' + (f' ({ctx})' if ctx else ''))
        report = '\n'.join(lines)
        result = {'decision': 'block', 'reason': f'Markdown lint issues (cannot auto-fix):\n{report}'}
        print(json.dumps(result))
except:
    pass
" 2>/dev/null)

        if [[ -n "$unfixable" ]]; then
            echo "$unfixable"
        fi
    fi
fi

exit 0
