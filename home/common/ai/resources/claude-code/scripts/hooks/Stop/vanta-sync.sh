#!/bin/bash
# Vanta sync reminder on Stop
# Checks if last sync was more than 24 hours ago and reminds to sync

cd "${CLAUDE_PROJECT_DIR:-.}"

# Exit silently if not linked to Vanta
[[ ! -f .beads/vanta.yaml ]] && exit 0

# Get last sync time from vanta.yaml
last_sync=$(grep "last_sync:" .beads/vanta.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')

# If never synced, remind to sync
if [[ -z "$last_sync" || "$last_sync" == "null" ]]; then
	echo "Vanta linked but never synced. Run /vanta-sync to import failing controls."
	exit 0
fi

# Convert last_sync to epoch and check age
age_hours=$(python3 -c "
from datetime import datetime, timezone
import sys
try:
    dt = datetime.fromisoformat('$last_sync'.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    age = (now - dt).total_seconds() / 3600
    print(int(age))
except:
    print(999)
" 2>/dev/null || echo 999)

# Remind if sync is older than 24 hours
if [[ "$age_hours" -gt 24 ]]; then
	echo "Vanta last synced ${age_hours}h ago. Consider running /vanta-sync for latest compliance status."
fi

exit 0
