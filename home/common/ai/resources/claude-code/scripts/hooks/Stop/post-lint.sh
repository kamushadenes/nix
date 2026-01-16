#!/usr/bin/env bash
# Run linter after Claude stops - blocks if lint fails

cd "${CLAUDE_PROJECT_DIR:-.}"

if ! command -v just &>/dev/null; then
	exit 0
fi

# Prefer lint-fix if available, otherwise use lint
if just --list 2>/dev/null | grep -q 'lint-fix'; then
	lint_cmd="lint-fix"
elif just --list 2>/dev/null | grep -q 'lint'; then
	lint_cmd="lint"
else
	exit 0
fi

output=$(just $lint_cmd 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
	python3 -c "
import json, sys
output = sys.stdin.read()
print(json.dumps({'decision': 'block', 'reason': 'Lint failed:\\n' + output}))
" <<<"$output"
	exit 0
fi

exit 0
