#!/usr/bin/env bash
#
# Session cleanup hook - runs when Claude Code session ends
#
# Responsibilities:
# 1. Clean up orphaned MCP server processes (no living Claude parent)
# 2. Log stale Claude processes for manual review
#
# Note: ccusage manages its own cache via --refresh-interval, no custom cleanup needed.
#
# This prevents resource accumulation from multiple/stale Claude sessions.
#

set -euo pipefail

#############################################################################
# 1. Clean up orphaned MCP processes
#
# Strategy: Find MCP processes whose parent is init (PID 1 on Linux) or
# launchd (PID 1 on macOS), meaning their original Claude parent is gone.
#############################################################################

cleanup_orphaned_mcp() {
    local mcp_pattern="$1"

    # Find processes matching pattern with PPID=1 (orphaned)
    # On macOS, PPID 1 means the process was re-parented to launchd
    pgrep -P 1 -f "$mcp_pattern" 2>/dev/null | while read -r pid; do
        # Verify it's actually an MCP-related process before killing
        if ps -p "$pid" -o args= 2>/dev/null | grep -qE "(mcp|task-master|orchestrator)"; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

# Clean up known MCP server patterns
cleanup_orphaned_mcp "slack-mcp-server"
cleanup_orphaned_mcp "vanta-mcp-server"
cleanup_orphaned_mcp "task-master-ai"
cleanup_orphaned_mcp "orchestrator-mcp"
cleanup_orphaned_mcp "github-mcp-server"
cleanup_orphaned_mcp "claude-in-chrome-mcp"
cleanup_orphaned_mcp "pyright.*langserver"

#############################################################################
# 2. Log stale Claude processes (>24 hours old, no TTY)
#
# These are likely zombie sessions that lost their terminal connection.
# Only clean up processes that:
# - Match "claude --" pattern
# - Are older than 24 hours
# - Have no controlling terminal (?)
#############################################################################

# Find claude processes older than 24h by checking /proc or ps elapsed time
# This is conservative - only kills truly stale processes
if command -v pgrep &>/dev/null; then
    pgrep -f "claude --" 2>/dev/null | while read -r pid; do
        # Get elapsed time in seconds (macOS and Linux compatible)
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS: ps etime format is [[dd-]hh:]mm:ss
            elapsed=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
        else
            # Linux: same format
            elapsed=$(ps -p "$pid" -o etimes= 2>/dev/null | tr -d ' ')
        fi

        # Parse elapsed time to seconds (simplified: if contains '-', it's >24h)
        if [[ "$elapsed" == *-* ]]; then
            # Process is days old - check if it has a TTY
            tty=$(ps -p "$pid" -o tty= 2>/dev/null | tr -d ' ')
            if [[ "$tty" == "?" ]] || [[ "$tty" == "??" ]]; then
                # No TTY and days old - likely a zombie, but log instead of kill
                # for safety (user can review and kill manually)
                echo "[session-cleanup] Found stale Claude process: PID=$pid, elapsed=$elapsed, tty=$tty" \
                    >> /tmp/claude-stale-processes.log 2>/dev/null || true
            fi
        fi
    done
fi

exit 0
