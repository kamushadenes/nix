#!/usr/bin/env bash
# Update GSD files in the nix config by running the installer in a temp dir
set -euo pipefail

NIX_CONFIG_GSD="${HOME}/.config/nix/config/home/common/ai/resources/claude-code/gsd"

# Create temp dir and install GSD locally
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing GSD to temp dir..."
cd "$tmpdir"
npm exec --yes -- get-shit-done-cc --claude --local 2>&1

echo ""
echo "Syncing files to nix config..."

# Full sync of all categories (--delete removes files dropped by upstream)
rsync -a --delete "$tmpdir/.claude/agents/" "$NIX_CONFIG_GSD/agents/"
rsync -a --delete "$tmpdir/.claude/commands/" "$NIX_CONFIG_GSD/commands/"
rsync -a --delete "$tmpdir/.claude/get-shit-done/" "$NIX_CONFIG_GSD/get-shit-done/"
rsync -a --delete "$tmpdir/.claude/hooks/" "$NIX_CONFIG_GSD/hooks/"

# Top-level metadata files
cp "$tmpdir/.claude/gsd-file-manifest.json" "$NIX_CONFIG_GSD/gsd-file-manifest.json"
cp "$tmpdir/.claude/settings.json" "$NIX_CONFIG_GSD/settings.json" 2>/dev/null || true
cp "$tmpdir/.claude/package.json" "$NIX_CONFIG_GSD/package.json" 2>/dev/null || true

# Remove any .bak files
find "$NIX_CONFIG_GSD" -name "*.bak" -delete

# Fix hardcoded temp dir paths — installer bakes absolute paths of the install
# directory into all markdown/js files. Replace with $HOME-based deploy target.
echo "Fixing hardcoded temp dir paths..."
find "$NIX_CONFIG_GSD" \( -name "*.md" -o -name "*.js" -o -name "*.json" -o -name "*.cjs" -o -name "*.sh" \) \
	-exec sed -i '' "s|${tmpdir}/.claude/|\$HOME/.claude/|g" {} +

# Show version
version=$(cat "$NIX_CONFIG_GSD/get-shit-done/VERSION")
echo ""
echo "GSD updated to v${version}"
echo ""
echo "Next steps:"
echo "  1. git add + commit the changes"
echo "  2. Run 'rebuild' to deploy"
