#!/bin/bash
set -e

# Source nix profile
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Source devbox global shellenv
if [ -f /etc/devbox_shellenv ]; then
    source /etc/devbox_shellenv
fi

# If project has devbox.json, source its shellenv too
if [ -f "devbox.json" ]; then
    eval "$(devbox shellenv 2>/dev/null)" || true
fi

# Force HOME to claude user (devbox shellenv may have set it to /root)
export HOME=/home/claude

# Copy claude config from staging area if present (allows modification)
if [ -d /tmp/claude-config-staging/.claude ]; then
    cp -r /tmp/claude-config-staging/.claude "$HOME/"
fi
if [ -f /tmp/claude-config-staging/.claude.json ]; then
    cp /tmp/claude-config-staging/.claude.json "$HOME/"
fi

echo "Starting Claude with --dangerously-skip-permissions..."
exec claude --dangerously-skip-permissions "$@"
