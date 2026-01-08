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

# Ensure home directory and config dirs exist with correct ownership
sudo mkdir -p "$HOME/.config/google-chrome" "$HOME/.cache"
sudo chown -R claude:claude "$HOME"

# Copy claude config from staging area if present (allows modification)
# Symlinks already dereferenced on host before mounting
if [ -d /tmp/claude-config-staging/.claude ]; then
    cp -r /tmp/claude-config-staging/.claude "$HOME/"
    # Clear auto-resume state but keep conversation history for /resume
    rm -f "$HOME/.claude/.last_"* 2>/dev/null || true
fi
if [ -f /tmp/claude-config-staging/.claude.json ]; then
    cp /tmp/claude-config-staging/.claude.json "$HOME/"
fi
# Copy credentials from keychain (mounted separately)
if [ -f /tmp/claude-credentials.json ]; then
    mkdir -p "$HOME/.claude"
    cp /tmp/claude-credentials.json "$HOME/.claude/.credentials.json"
fi

# Copy all staged credentials to home directory
if [ -d /tmp/creds-staging/.ssh ]; then
    cp -r /tmp/creds-staging/.ssh "$HOME/"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
fi
if [ -f /tmp/creds-staging/.gitconfig ]; then
    cp /tmp/creds-staging/.gitconfig "$HOME/"
fi
if [ -d /tmp/creds-staging/.aws ]; then
    cp -r /tmp/creds-staging/.aws "$HOME/"
fi
if [ -d /tmp/creds-staging/.config/gcloud ]; then
    mkdir -p "$HOME/.config"
    cp -r /tmp/creds-staging/.config/gcloud "$HOME/.config/"
fi
if [ -d /tmp/creds-staging/.kube ]; then
    cp -r /tmp/creds-staging/.kube "$HOME/"
fi
if [ -d /tmp/creds-staging/agenix ]; then
    sudo mkdir -p /run/agenix
    sudo cp -r /tmp/creds-staging/agenix/* /run/agenix/ 2>/dev/null || true
    sudo chmod -R 400 /run/agenix/* 2>/dev/null || true
fi

echo "Starting Claude with --dangerously-skip-permissions..."
exec claude --dangerously-skip-permissions "$@"
