# Decrypt cache signing key if needed
if test -f "@cacheKeyAgePath@" && test ! -f "@cacheKeyPath@"
  echo "Decrypting cache signing key..."
  if test -f "@ageIdentity@"
    @ageBin@ -d -i "@ageIdentity@" "@cacheKeyAgePath@" > "@cacheKeyPath@"
    if test $status -ne 0
      echo "Failed to decrypt cache key"
      return 1
    end
    chmod 600 "@cacheKeyPath@"
  else
    echo "Warning: Age identity not found at @ageIdentity@, skipping cache key decryption"
  end
end

# Check for remote deployment target
if test (count $argv) -gt 0 && test $argv[1] = "aether"
  # Remote deploy from macOS using --fast flag (skips rebuilding nixos-rebuild for target platform)
  echo "Deploying to aether (remote build)..."
  nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
    --fast \
    --flake ~/.config/nix/config#aether \
    --target-host aether \
    --build-host aether \
    --use-remote-sudo
else
  # Local rebuild
  @nhCommand@
end
