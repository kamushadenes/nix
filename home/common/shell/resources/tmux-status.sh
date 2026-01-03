#!/usr/bin/env bash
#
# tmux status helper script
# Outputs orchestrator job count only (git info is in Claude Code statusline)
#

set -euo pipefail

# Orchestrator database path
readonly ORCH_DB="$HOME/.config/orchestrator-mcp/state.db"

# Get running orchestrator jobs count
if [[ -f "$ORCH_DB" ]]; then
    count=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM jobs WHERE status='running'" 2>/dev/null || echo 0)
    if [[ "$count" -gt 0 ]]; then
        echo "🤖 $count "
    fi
fi
