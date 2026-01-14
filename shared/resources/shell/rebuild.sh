# Decrypt cache signing key if needed
if test -f "@cacheKeyAgePath@" && test ! -f "@cacheKeyPath@"; then
  echo "Decrypting cache signing key..."
  if test -f "@ageIdentity@"; then
    @ageBin@ -d -i "@ageIdentity@" "@cacheKeyAgePath@" > "@cacheKeyPath@"
    if test $? -ne 0; then
      echo "Failed to decrypt cache key"
      return 1
    fi
    chmod 600 "@cacheKeyPath@"
  else
    echo "Warning: Age identity not found at @ageIdentity@, skipping cache key decryption"
  fi
fi

# Check for remote deployment target
if test "$1" = "aether"; then
  # Remote deploy to aether - SSH in and build there (can't cross-compile from macOS)
  echo "Deploying to aether (SSH + remote build)..."
  ssh aether "cd ~/.config/nix/config && git pull && sudo nixos-rebuild switch --flake .#aether --impure"
  return $?
else
  # Local rebuild and propagate exit code
  @nhCommand@
  return $?
fi
