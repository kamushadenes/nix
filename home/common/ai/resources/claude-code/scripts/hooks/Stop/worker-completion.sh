#!/usr/bin/env bash
# Update .orchestrator/task_status on session end if in worker mode
# This ensures the orchestrator knows if a worker ended unexpectedly
#
# Workers write to task_progress, the heartbeat hook merges it into task_status.
# On session end, this hook checks both files and marks as stuck if no final status.

ORCHESTRATOR_DIR=".orchestrator"
TASK_FILE="$ORCHESTRATOR_DIR/current_task.md"
STATUS_FILE="$ORCHESTRATOR_DIR/task_status"
PROGRESS_FILE="$ORCHESTRATOR_DIR/task_progress"

# Only run in worker mode (task file exists)
if [[ ! -f "$TASK_FILE" ]]; then
    exit 0
fi

# First, merge any final progress into status
if [[ -f "$PROGRESS_FILE" ]]; then
    python3 -c "
import json
import os

STATUS_FILE = '$STATUS_FILE'
PROGRESS_FILE = '$PROGRESS_FILE'

# Load existing status
try:
    with open(STATUS_FILE, 'r') as f:
        status = json.load(f)
except:
    status = {}

# Merge progress into status
try:
    with open(PROGRESS_FILE, 'r') as f:
        progress = json.load(f)
    status.update(progress)
except:
    pass

# Write merged status
with open(STATUS_FILE, 'w') as f:
    json.dump(status, f, indent=2)
" 2>/dev/null
fi

# Check if status was already set (normal completion)
if [[ -f "$STATUS_FILE" ]]; then
    # Read current status
    current_status=$(python3 -c "
import json
import sys
try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
    print(data.get('status', ''))
except:
    print('')
" 2>/dev/null)

    if [[ "$current_status" == "completed" ]] || [[ "$current_status" == "failed" ]]; then
        # Already has final status, nothing to do
        exit 0
    fi

    # Session ended without completion - mark as stuck
    python3 -c "
import json
try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {}

data['status'] = 'stuck'
data['error'] = 'Session ended unexpectedly'

with open('$STATUS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
else
    # No status file at all - create one marked as stuck
    echo '{"status": "stuck", "error": "Session ended without status update"}' > "$STATUS_FILE"
fi
