#!/bin/bash
# ClickUp sync reminder on Stop
# Checks if beads changed since last ClickUp sync and reminds to sync

cd "${CLAUDE_PROJECT_DIR:-.}"

# Exit silently if not linked to ClickUp
[[ ! -f .beads/clickup.yaml ]] && exit 0

# Exit silently if no beads directory
[[ ! -f .beads/issues.jsonl ]] && exit 0

# Get last sync time from clickup.yaml
last_sync=$(grep "last_sync:" .beads/clickup.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')

# If never synced, remind to sync
if [[ -z "$last_sync" || "$last_sync" == "null" ]]; then
	echo "ClickUp linked but never synced. Run /clickup-sync to import tasks."
	exit 0
fi

# Get the mtime of issues.jsonl
issues_mtime=$(stat -f %m .beads/issues.jsonl 2>/dev/null || stat -c %Y .beads/issues.jsonl 2>/dev/null)

# Convert last_sync to epoch (handles ISO 8601 format)
# Using python for reliable cross-platform date parsing
last_sync_epoch=$(python3 -c "
from datetime import datetime
import sys
try:
    dt = datetime.fromisoformat('$last_sync'.replace('Z', '+00:00'))
    print(int(dt.timestamp()))
except:
    print(0)
" 2>/dev/null || echo 0)

# Compare timestamps
if [[ "$issues_mtime" -gt "$last_sync_epoch" ]]; then
	echo "Beads issues changed since last ClickUp sync. Consider running /clickup-sync."
fi

exit 0
