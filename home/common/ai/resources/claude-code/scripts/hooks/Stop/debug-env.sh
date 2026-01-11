#!/bin/bash
# Debug hook to log environment variables
exec >> /tmp/claude-stop-hook-debug.log 2>&1
echo "=== Stop hook called at $(date) ==="
echo "PWD: $PWD"
echo "CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-NOT SET}"
echo "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-NOT SET}"
echo "All CLAUDE_* vars:"
env | grep -i claude || echo "No CLAUDE vars found"
echo "=== End debug ==="
exit 0
