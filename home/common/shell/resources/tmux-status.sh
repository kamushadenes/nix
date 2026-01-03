#!/usr/bin/env bash
#
# tmux status helper script
# Outputs orchestrator running job count
#

set -euo pipefail

# Orchestrator database path
readonly ORCH_DB="$HOME/.config/orchestrator-mcp/state.db"

output=""

if [[ -f "$ORCH_DB" ]]; then
    # Get running orchestrator jobs count
    jobs=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM jobs WHERE status='running'" 2>/dev/null || echo 0)
    if [[ "$jobs" -gt 0 ]]; then
        output+="🤖$jobs"
    fi
fi

echo "$output"
