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

# Check for remote deployment target or docker build
case "${1:-}" in
  aether)
    # Remote deploy from macOS using --fast flag (skips rebuilding nixos-rebuild for target platform)
    echo "Deploying to aether (remote build)..."
    nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
      --fast \
      --impure \
      --flake "$FLAKE_PATH#aether" \
      --target-host aether \
      --build-host aether \
      --use-remote-sudo
    ;;
  docker)
    # Build multi-arch NixOS Docker image
    IMAGE_NAME="nixos-claude-sandbox"

    echo "Building Docker image for x86_64-linux..."
    nix build "$FLAKE_PATH#packages.x86_64-linux.docker" --impure -o result-x86_64

    echo "Building Docker image for aarch64-linux..."
    nix build "$FLAKE_PATH#packages.aarch64-linux.docker" --impure -o result-aarch64

    echo ""
    echo "Loading images into Docker..."
    X86_IMAGE=$(docker load < result-x86_64 | sed -n 's/Loaded image: //p')
    ARM_IMAGE=$(docker load < result-aarch64 | sed -n 's/Loaded image: //p')

    # Tag with architecture suffix
    docker tag "$X86_IMAGE" "$IMAGE_NAME:amd64"
    docker tag "$ARM_IMAGE" "$IMAGE_NAME:arm64"

    # Create multi-arch manifest
    echo "Creating multi-arch manifest..."
    docker manifest rm "$IMAGE_NAME:latest" 2>/dev/null || true
    docker manifest create "$IMAGE_NAME:latest" \
      --amend "$IMAGE_NAME:amd64" \
      --amend "$IMAGE_NAME:arm64"

    # Cleanup result symlinks
    rm -f result-x86_64 result-aarch64

    echo ""
    echo "Multi-arch image created: $IMAGE_NAME:latest"
    echo "  - $IMAGE_NAME:amd64 (x86_64)"
    echo "  - $IMAGE_NAME:arm64 (aarch64)"
    ;;
  *)
    # Local rebuild
    eval "$NH_COMMAND"
    ;;
esac
