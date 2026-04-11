#!/usr/bin/env bash
# Devbox/direnv setup hook - Installs devbox and initializes direnv on web
#
# This hook runs ONLY in the web environment (Codex CLI on the web).
# It checks for devbox.json and sets up the development environment.

set -euo pipefail

# Parse cwd from stdin JSON
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
if [[ -n "$CWD" ]]; then
    cd "$CWD"
fi

# Only run in web/remote environment
# CODEX_REMOTE is "true" when running on web, empty/unset locally
if [[ "${CODEX_REMOTE:-}" != "true" && "${CLAUDE_CODE_REMOTE:-}" != "true" ]]; then
    exit 0
fi

# Only run if devbox.json exists in the project
if [[ ! -f "devbox.json" ]]; then
    exit 0
fi

# Ensure an env file is set (used to persist env vars for subsequent bash commands)
ENV_FILE="${CODEX_ENV_FILE:-${CLAUDE_ENV_FILE:-}}"
if [[ -z "$ENV_FILE" ]]; then
    exit 0
fi

# Install devbox if not present
if ! command -v devbox &>/dev/null; then
    echo "Installing devbox..."
    curl -fsSL https://get.jetify.com/devbox 2>/dev/null | bash 2>/dev/null || {
        echo "Failed to install devbox"
        exit 0
    }
fi

# Run direnv allow if direnv is available
if command -v direnv &>/dev/null; then
    echo "Running direnv allow..."
    direnv allow . 2>/dev/null || true

    # Export direnv environment to env file
    eval "$(direnv export bash 2>/dev/null)" 2>/dev/null || true
fi

# Initialize devbox shell environment and export to env file
# This ensures subsequent bash commands have access to devbox packages
echo "Initializing devbox environment..."
if command -v devbox &>/dev/null; then
    # Use devbox shellenv to get environment variables
    # and append them to env file for persistence
    devbox shellenv 2>/dev/null >> "$ENV_FILE" || true
fi

echo "Devbox environment ready"
exit 0
