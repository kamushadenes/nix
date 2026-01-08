# /sync-ai-dev - Sync AI resources to ai-dev repository

Sync resources from the Nix configuration to the standalone ai-dev repository for team use.

## Behavior

1. Check that ai-dev repo exists at `~/Dropbox/Projects/Iniciador/ai-dev`
2. Copy resources (agents, commands, rules, skills, hooks, orchestrator)
3. Show git diff of changes
4. Prompt for commit message
5. Commit and push to origin

## Sync Mapping

| Source (Nix) | Target (ai-dev) |
|--------------|-----------------|
| `resources/claude-code/agents/` | `resources/claude-code/agents/` |
| `resources/claude-code/commands/` | `resources/claude-code/commands/` |
| `resources/claude-code/rules/` | `resources/claude-code/rules/` |
| `resources/claude-code/skills/` | `resources/claude-code/skills/` |
| `resources/claude-code/memory/` | `resources/claude-code/memory/` |
| `resources/claude-code/scripts/` | `resources/claude-code/scripts/` |
| `resources/claude-code/config/` | `resources/claude-code/config/` |

## Exclusions

- `sync-ai-dev.md` (this file - nix repo only)
- `*.nix` files
- `__pycache__/` directories
- Private content from `private/` submodule

## Instructions

When the user runs `/sync-ai-dev`:

1. **Verify ai-dev repo exists:**
   ```bash
   ls -la ~/Dropbox/Projects/Iniciador/ai-dev/.git
   ```

2. **Run rsync for each resource directory:**
   ```bash
   SOURCE="$HOME/.config/nix/config/home/common/ai/resources/claude-code"
   TARGET="$HOME/Dropbox/Projects/Iniciador/ai-dev/resources/claude-code"

   # Sync each directory
   rsync -av --delete \
     --exclude='sync-ai-dev.md' \
     --exclude='*.nix' \
     --exclude='__pycache__' \
     --exclude='.DS_Store' \
     "$SOURCE/agents/" "$TARGET/agents/"

   rsync -av --delete \
     --exclude='sync-ai-dev.md' \
     --exclude='*.nix' \
     --exclude='__pycache__' \
     --exclude='.DS_Store' \
     "$SOURCE/commands/" "$TARGET/commands/"

   rsync -av --delete \
     --exclude='*.nix' \
     --exclude='__pycache__' \
     --exclude='.DS_Store' \
     "$SOURCE/rules/" "$TARGET/rules/"

   rsync -av --delete \
     --exclude='*.nix' \
     --exclude='__pycache__' \
     --exclude='.DS_Store' \
     "$SOURCE/skills/" "$TARGET/skills/"

   rsync -av --delete \
     --exclude='*.nix' \
     --exclude='__pycache__' \
     --exclude='.DS_Store' \
     "$SOURCE/memory/" "$TARGET/memory/"

   rsync -av --delete \
     --exclude='*.nix' \
     --exclude='__pycache__' \
     --exclude='.DS_Store' \
     "$SOURCE/scripts/" "$TARGET/scripts/"

   rsync -av --delete \
     --exclude='*.nix' \
     --exclude='__pycache__' \
     --exclude='.DS_Store' \
     "$SOURCE/config/" "$TARGET/config/"
   ```

3. **Show changes:**
   ```bash
   cd ~/Dropbox/Projects/Iniciador/ai-dev
   git status
   git diff --stat
   ```

4. **If there are changes, ask user for commit message and commit:**
   ```bash
   git add -A
   git commit -m "<user-provided message>"
   git push
   ```

5. **Report completion with summary of synced files.**
