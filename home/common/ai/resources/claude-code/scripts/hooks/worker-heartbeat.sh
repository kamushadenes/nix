#!/usr/bin/env bash
# Update .orchestrator/task_status from hook input if in worker mode
# This extracts context from the tool being used and updates task_status
#
# Workers write to .orchestrator/task_progress (never task_status directly)
# This hook merges task_progress into task_status and updates heartbeat
#
# Called from multiple hook types:
# - PreToolUse (tool_name, tool_input available)
# - PostToolUse (tool_name, tool_input available)
# - PreCompact
# - SubagentStop

ORCHESTRATOR_DIR=".orchestrator"
TASK_FILE="$ORCHESTRATOR_DIR/current_task.md"
STATUS_FILE="$ORCHESTRATOR_DIR/task_status"
PROGRESS_FILE="$ORCHESTRATOR_DIR/task_progress"

# Only run in worker mode (detected by presence of .orchestrator/current_task.md)
if [[ ! -f "$TASK_FILE" ]]; then
    exit 0
fi

# Read hook input from stdin (may be empty for some hook types)
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')

# Create status file if it doesn't exist yet
if [[ ! -f "$STATUS_FILE" ]]; then
    echo '{"status": "working"}' > "$STATUS_FILE"
fi

# Update task_status with hook context and merge task_progress
python3 -c "
import json
from datetime import datetime, timezone
import os
import sys

STATUS_FILE = '$STATUS_FILE'
PROGRESS_FILE = '$PROGRESS_FILE'
HOOK_INPUT = '''$HOOK_INPUT'''

# Load existing status
try:
    with open(STATUS_FILE, 'r') as f:
        status = json.load(f)
except:
    status = {}

# If task_progress exists, merge it into status (progress takes precedence)
if os.path.exists(PROGRESS_FILE):
    try:
        with open(PROGRESS_FILE, 'r') as f:
            progress = json.load(f)
        # Merge progress into status (progress values override status values)
        status.update(progress)
    except:
        pass

# Extract context from hook input
try:
    hook_data = json.loads(HOOK_INPUT) if HOOK_INPUT.strip() else {}
except:
    hook_data = {}

tool_name = hook_data.get('tool_name', '')
tool_input = hook_data.get('tool_input') or {}

# Build current_action from tool context
current_action = None
if tool_name:
    if tool_name in ('Edit', 'Write', 'MultiEdit'):
        file_path = tool_input.get('file_path', '')
        if file_path:
            filename = os.path.basename(file_path)
            current_action = f'editing {filename}'
    elif tool_name == 'Read':
        file_path = tool_input.get('file_path', '')
        if file_path:
            filename = os.path.basename(file_path)
            current_action = f'reading {filename}'
    elif tool_name == 'Bash':
        command = tool_input.get('command', '')
        if command:
            # Truncate long commands
            if len(command) > 50:
                command = command[:47] + '...'
            current_action = f'running: {command}'
    elif tool_name in ('Grep', 'Glob'):
        pattern = tool_input.get('pattern', '')
        if pattern:
            current_action = f'searching for: {pattern}'
    elif tool_name == 'Task':
        desc = tool_input.get('description', '')
        if desc:
            current_action = f'spawning agent: {desc}'
    else:
        current_action = f'using {tool_name}'

# Update status with context
if current_action:
    status['current_action'] = current_action
    status['last_tool'] = tool_name

# Always update heartbeat
status['heartbeat'] = datetime.now(timezone.utc).isoformat()

# Write merged status
with open(STATUS_FILE, 'w') as f:
    json.dump(status, f, indent=2)
" 2>/dev/null

exit 0
