#!/usr/bin/env bash
# Update GSD files for OpenCode in the nix config by running the installer in a temp dir
set -euo pipefail

NIX_CONFIG_GSD="${HOME}/.config/nix/config/home/common/ai/resources/opencode/gsd"

# Create temp dir and install GSD locally
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing GSD for OpenCode to temp dir..."
cd "$tmpdir"
npm install get-shit-done-cc >/dev/null 2>&1
./node_modules/.bin/get-shit-done-cc --opencode --local 2>&1

echo ""
echo "Syncing files to nix config..."

# Sync each category (delete removed files, add new ones)
if [ -d "$tmpdir/.opencode/agents" ]; then
  mkdir -p "$NIX_CONFIG_GSD/agents"
  rsync -a --delete "$tmpdir/.opencode/agents/" "$NIX_CONFIG_GSD/agents/"
fi
if [ -d "$tmpdir/.opencode/command" ]; then
  mkdir -p "$NIX_CONFIG_GSD/command"
  rsync -a --delete "$tmpdir/.opencode/command/" "$NIX_CONFIG_GSD/command/"
fi
if [ -d "$tmpdir/.opencode/get-shit-done" ]; then
  mkdir -p "$NIX_CONFIG_GSD/get-shit-done"
  rsync -a --delete "$tmpdir/.opencode/get-shit-done/" "$NIX_CONFIG_GSD/get-shit-done/"
fi
if [ -d "$tmpdir/.opencode/hooks" ]; then
  mkdir -p "$NIX_CONFIG_GSD/hooks"
  rsync -a --delete "$tmpdir/.opencode/hooks/" "$NIX_CONFIG_GSD/hooks/"
fi
# Copy root JSON/config files
for f in gsd-file-manifest.json opencode.json package.json settings.json; do
  if [ -f "$tmpdir/.opencode/$f" ]; then
    cp "$tmpdir/.opencode/$f" "$NIX_CONFIG_GSD/$f"
  fi
done

# Remove any .bak files
find "$NIX_CONFIG_GSD" -name "*.bak" -delete 2>/dev/null || true

# Show version
if [ -f "$NIX_CONFIG_GSD/get-shit-done/VERSION" ]; then
  version=$(cat "$NIX_CONFIG_GSD/get-shit-done/VERSION")
  echo ""
  echo "GSD (OpenCode) updated to v${version}"
fi
echo ""
echo "Next steps:"
echo "  1. git add + commit the changes"
echo "  2. Run 'rebuild' to deploy"
