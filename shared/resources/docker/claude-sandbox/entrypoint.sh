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

echo "Starting Claude with --dangerously-skip-permissions..."
exec claude --dangerously-skip-permissions "$@"
