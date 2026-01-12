#!/usr/bin/env bash
# Inject .orchestrator/current_task.md content if present (for worker instances)
# This hook runs on SessionStart and outputs task context for workers

ORCHESTRATOR_DIR=".orchestrator"
TASK_FILE="$ORCHESTRATOR_DIR/current_task.md"

if [[ -f "$TASK_FILE" ]]; then
    echo "=== WORKER MODE ACTIVE ==="
    echo "You are a task worker instance. A task has been assigned to you."
    echo ""
    cat "$TASK_FILE"
    echo ""
    echo "=== AWAITING /work COMMAND ==="
    echo "The orchestrator will send /work to begin autonomous execution."
fi
