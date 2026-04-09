#!/usr/bin/env bash
# Update GSD files in the nix config by running the installer in a temp dir
set -euo pipefail

NIX_CONFIG_GSD="${HOME}/.config/nix/config/home/common/ai/resources/opencode/gsd"

# Create temp dir and install GSD locally
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing GSD to temp dir..."
cd "$tmpdir"
npm exec --yes -- get-shit-done-cc --opencode --local 2>&1

echo ""
echo "Syncing files to nix config..."

# Full sync of all categories (--delete removes files dropped by upstream)
rsync -a --delete "$tmpdir/.opencode/agents/" "$NIX_CONFIG_GSD/agents/"
rsync -a --delete "$tmpdir/.opencode/command/" "$NIX_CONFIG_GSD/command/"
rsync -a --delete "$tmpdir/.opencode/get-shit-done/" "$NIX_CONFIG_GSD/get-shit-done/"
rsync -a --delete "$tmpdir/.opencode/hooks/" "$NIX_CONFIG_GSD/hooks/"

# Top-level metadata files
cp "$tmpdir/.opencode/gsd-file-manifest.json" "$NIX_CONFIG_GSD/gsd-file-manifest.json"
cp "$tmpdir/.opencode/settings.json" "$NIX_CONFIG_GSD/settings.json" 2>/dev/null || true
cp "$tmpdir/.opencode/opencode.json" "$NIX_CONFIG_GSD/opencode.json" 2>/dev/null || true
cp "$tmpdir/.opencode/package.json" "$NIX_CONFIG_GSD/package.json" 2>/dev/null || true

# Remove any .bak files
find "$NIX_CONFIG_GSD" -name "*.bak" -delete

# Fix hardcoded temp dir paths — installer bakes absolute paths of the install
# directory into all markdown/js files. Replace with $HOME-based deploy target.
echo "Fixing hardcoded temp dir paths..."
find "$NIX_CONFIG_GSD" \( -name "*.md" -o -name "*.js" -o -name "*.json" -o -name "*.cjs" -o -name "*.sh" \) \
	-exec sed -i '' "s|${tmpdir}/.opencode/|\$HOME/.config/opencode/|g" {} +

# Fix command naming — installer uses Claude Code's colon convention (gsd:quick)
# but OpenCode commands use hyphens (gsd-quick).
echo "Fixing command naming (gsd: → gsd-)..."
find "$NIX_CONFIG_GSD" \( -name "*.md" -o -name "*.js" -o -name "*.json" -o -name "*.cjs" \) \
	-exec sed -i '' 's|gsd:|gsd-|g' {} +

# Show version
version=$(cat "$NIX_CONFIG_GSD/get-shit-done/VERSION")
echo ""
echo "GSD updated to v${version}"
echo ""
echo "Next steps:"
echo "  1. git add + commit the changes"
echo "  2. Run 'rebuild' to deploy"
