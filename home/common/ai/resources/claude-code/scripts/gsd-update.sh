#!/usr/bin/env bash
# Update GSD files in the nix config by running the installer in a temp dir
set -euo pipefail

NIX_CONFIG_GSD="${HOME}/.config/nix/config/home/common/ai/resources/claude-code/gsd"

# Create temp dir and install GSD locally
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing GSD to temp dir..."
cd "$tmpdir"
npx get-shit-done-cc --claude --local 2>&1

echo ""
echo "Syncing files to nix config..."

# Sync each category (delete removed files, add new ones)
rsync -a --delete "$tmpdir/.claude/agents/gsd-"* "$NIX_CONFIG_GSD/agents/"
rsync -a --delete "$tmpdir/.claude/commands/gsd/" "$NIX_CONFIG_GSD/commands/gsd/"
rsync -a --delete "$tmpdir/.claude/get-shit-done/" "$NIX_CONFIG_GSD/get-shit-done/"
rsync -a --delete "$tmpdir/.claude/hooks/gsd-"* "$NIX_CONFIG_GSD/hooks/"
cp "$tmpdir/.claude/gsd-file-manifest.json" "$NIX_CONFIG_GSD/gsd-file-manifest.json"

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
