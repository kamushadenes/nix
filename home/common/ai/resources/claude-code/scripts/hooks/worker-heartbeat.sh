#!/usr/bin/env bash
# Update .orchestrator/task_status heartbeat timestamp if in worker mode
# This lets the orchestrator know the worker is still active
#
# Called from multiple hook types:
# - PreToolUse
# - PostToolUse
# - PreCompact
# - SubagentStop

ORCHESTRATOR_DIR=".orchestrator"
TASK_FILE="$ORCHESTRATOR_DIR/current_task.md"
STATUS_FILE="$ORCHESTRATOR_DIR/task_status"

# Only run in worker mode (detected by presence of .orchestrator/current_task.md)
if [[ ! -f "$TASK_FILE" ]]; then
    exit 0
fi

# Create status file if it doesn't exist yet
if [[ ! -f "$STATUS_FILE" ]]; then
    echo '{"status": "working"}' > "$STATUS_FILE"
fi

# Update heartbeat timestamp in status file
python3 -c "
import json
from datetime import datetime, timezone

try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {}

data['heartbeat'] = datetime.now(timezone.utc).isoformat()

with open('$STATUS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null

exit 0
