---
allowed-tools: Bash(~/.claude/scripts/gsd-update.sh), Bash(git:*), Bash(rebuild:*)
description: Update GSD framework to latest version
---

## Your task

Run the GSD update script, then commit and rebuild:

1. Run `~/.claude/scripts/gsd-update.sh`
2. Stage and commit the updated files in the nix config
3. Run `rebuild` to deploy
