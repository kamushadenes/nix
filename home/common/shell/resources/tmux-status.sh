#!/usr/bin/env bash
#
# tmux status helper script
# Outputs orchestrator job and task counts
#

set -euo pipefail

# Orchestrator database path
readonly ORCH_DB="$HOME/.config/orchestrator-mcp/state.db"

output=""

if [[ -f "$ORCH_DB" ]]; then
    # Get running orchestrator jobs count
    jobs=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM jobs WHERE status='running'" 2>/dev/null || echo 0)
    if [[ "$jobs" -gt 0 ]]; then
        output+="🤖$jobs "
    fi

    # Get task counts by active status
    discussing=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM tasks WHERE status='discussing'" 2>/dev/null || echo 0)
    in_progress=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM tasks WHERE status='in_progress'" 2>/dev/null || echo 0)
    review=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM tasks WHERE status='review'" 2>/dev/null || echo 0)
    qa=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM tasks WHERE status='qa'" 2>/dev/null || echo 0)
    blocked=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM tasks WHERE status='blocked'" 2>/dev/null || echo 0)

    # Build task status string (only show non-zero counts)
    tasks=""
    [[ "$discussing" -gt 0 ]] && tasks+="💬$discussing "
    [[ "$in_progress" -gt 0 ]] && tasks+="🔨$in_progress "
    [[ "$review" -gt 0 ]] && tasks+="👀$review "
    [[ "$qa" -gt 0 ]] && tasks+="✅$qa "
    [[ "$blocked" -gt 0 ]] && tasks+="🚫$blocked "

    output+="$tasks"
fi

# Trim trailing space and output
echo "${output% }"
