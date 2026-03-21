#!/usr/bin/env bash
# Update GSD files in the nix config by running the installer in a temp dir
set -euo pipefail

NIX_CONFIG_GSD="${HOME}/.config/nix/config/home/common/ai/resources/opencode/gsd"

# Create temp dir and install GSD locally
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing GSD to temp dir..."
cd "$tmpdir"
npx get-shit-done-cc --opencode --local 2>&1

echo ""
echo "Syncing files to nix config..."

# Sync each category (delete removed files, add new ones)
rsync -a --delete "$tmpdir/.opencode/agents/gsd-"* "$NIX_CONFIG_GSD/agents/"
rsync -a --delete "$tmpdir/.opencode/command/" "$NIX_CONFIG_GSD/command/"
rsync -a --delete "$tmpdir/.opencode/get-shit-done/" "$NIX_CONFIG_GSD/get-shit-done/"
rsync -a --delete "$tmpdir/.opencode/hooks/gsd-"* "$NIX_CONFIG_GSD/hooks/"
cp "$tmpdir/.opencode/gsd-file-manifest.json" "$NIX_CONFIG_GSD/gsd-file-manifest.json"
cp "$tmpdir/.opencode/package.json" "$NIX_CONFIG_GSD/package.json"

# Remove any .bak files
find "$NIX_CONFIG_GSD" -name "*.bak" -delete

# Show version
version=$(cat "$NIX_CONFIG_GSD/get-shit-done/VERSION")
echo ""
echo "GSD updated to v${version}"
echo ""
echo "Next steps:"
echo "  1. git add + commit the changes"
echo "  2. Run 'rebuild' to deploy"
