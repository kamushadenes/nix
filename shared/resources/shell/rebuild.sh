#!/usr/bin/env bash
# Rebuild NixOS/Darwin configuration
# Standalone script that works in all shells

set -euo pipefail

# Configuration (substituted by Nix)
CACHE_KEY_PATH="@cacheKeyPath@"
CACHE_KEY_AGE_PATH="@cacheKeyAgePath@"
AGE_IDENTITY="@ageIdentity@"
AGE_BIN="@ageBin@"
NH_COMMAND="@nhCommand@"
FLAKE_PATH="$HOME/.config/nix/config"

# Decrypt cache signing key if needed
if [[ -f "$CACHE_KEY_AGE_PATH" ]] && [[ ! -f "$CACHE_KEY_PATH" ]]; then
  echo "Decrypting cache signing key..."
  if [[ -f "$AGE_IDENTITY" ]]; then
    "$AGE_BIN" -d -i "$AGE_IDENTITY" "$CACHE_KEY_AGE_PATH" > "$CACHE_KEY_PATH"
    chmod 600 "$CACHE_KEY_PATH"
  else
    echo "Warning: Age identity not found at $AGE_IDENTITY, skipping cache key decryption"
  fi
fi

# Check for remote deployment target
if [[ "${1:-}" == "aether" ]]; then
  # Remote deploy from macOS using --fast flag (skips rebuilding nixos-rebuild for target platform)
  echo "Deploying to aether (remote build)..."
  nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
    --fast \
    --impure \
    --flake "$FLAKE_PATH#aether" \
    --target-host aether \
    --build-host aether \
    --use-remote-sudo
else
  # Local rebuild
  eval "$NH_COMMAND"
fi
