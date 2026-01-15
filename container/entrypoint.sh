#!/usr/bin/env bash
# Container entrypoint for NixOS Claude sandbox
# Handles:
# 1. Environment variable setup
# 2. Host agent mounting (SSH, GPG)
# 3. Optional secrets linking
# 4. Shell or command execution

set -e

export HOME="${HOME:-/home/kamushadenes}"
export USER="${USER:-kamushadenes}"

# Setup XDG directories
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" 2>/dev/null || true
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# SSH agent from host (mounted at /run/host-ssh-agent)
if [ -S "/run/host-ssh-agent" ]; then
    export SSH_AUTH_SOCK="/run/host-ssh-agent"
fi

# GPG agent from host (mounted at /run/host-gpg-agent)
if [ -S "/run/host-gpg-agent" ]; then
    export GPG_AGENT_INFO="/run/host-gpg-agent"
fi

# Link mounted secrets if present
if [ -d "/run/secrets" ]; then
    mkdir -p "$HOME/.age" "$HOME/.ssh" 2>/dev/null || true

    # Age identity
    if [ -f "/run/secrets/age.pem" ]; then
        ln -sf /run/secrets/age.pem "$HOME/.age/age.pem"
        chmod 600 "$HOME/.age/age.pem" 2>/dev/null || true
    fi

    # SSH keys
    if [ -f "/run/secrets/id_ed25519" ]; then
        ln -sf /run/secrets/id_ed25519 "$HOME/.ssh/id_ed25519"
        chmod 600 "$HOME/.ssh/id_ed25519" 2>/dev/null || true
    fi
    if [ -f "/run/secrets/id_ed25519.pub" ]; then
        ln -sf /run/secrets/id_ed25519.pub "$HOME/.ssh/id_ed25519.pub"
    fi

    # GPG directory
    if [ -d "/run/secrets/gnupg" ]; then
        mkdir -p "$HOME/.gnupg" 2>/dev/null || true
        chmod 700 "$HOME/.gnupg"
        for f in /run/secrets/gnupg/*; do
            [ -e "$f" ] && ln -sf "$f" "$HOME/.gnupg/"
        done
    fi
fi

# Source nix profile if available
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Add nix profile to PATH
export PATH="$HOME/.nix-profile/bin:$PATH"

# Execute command or start shell
if [ $# -eq 0 ]; then
    exec fish -l
else
    exec "$@"
fi
