# /sync-ai-dev - Sync AI resources to ai-dev repository

Sync resources from the Nix configuration to the standalone ai-dev repository for team use.

## Behavior

1. Check that ai-dev repo exists at `~/Dropbox/Projects/Iniciador/ai-dev`
2. Copy resources (agents, commands, rules, skills, hooks, orchestrator)
3. Show git diff of changes
4. Prompt for commit message
5. Commit and push to origin

## Sync Mapping

| Source (Nix)                              | Target (ai-dev)                                                              |
| ----------------------------------------- | ---------------------------------------------------------------------------- |
| `resources/claude-code/agents/`           | `resources/claude-code/agents/`                                              |
| `resources/claude-code/commands/`         | `resources/claude-code/commands/`                                            |
| `resources/claude-code/rules/`            | `resources/claude-code/rules/`                                               |
| `resources/claude-code/skills/`           | `resources/claude-code/skills/`                                              |
| `resources/claude-code/memory/`           | `resources/claude-code/memory/`                                              |
| `resources/claude-code/scripts/`          | `resources/claude-code/scripts/`                                             |
| `resources/claude-code/config/`           | `resources/claude-code/config/`                                              |
| `shared/resources/shell/claude-tmux.fish` | `resources/shell/fish/functions/c.fish`                                      |
| `shared/resources/shell/claude-tmux.sh`   | `resources/shell/bash/c.sh`                                                  |
| (generated)                               | `resources/shell/env.sh` (Claude environment variables)                      |
| (generated)                               | `resources/shell/fish/conf.d/claude-env.fish` (Claude environment variables) |

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

   # Sync shell functions
   SHELL_SOURCE="$HOME/.config/nix/config/shared/resources/shell"
   SHELL_TARGET="$HOME/Dropbox/Projects/Iniciador/ai-dev/resources/shell"

   mkdir -p "$SHELL_TARGET/fish/functions" "$SHELL_TARGET/fish/conf.d" "$SHELL_TARGET/bash"
   cp "$SHELL_SOURCE/claude-tmux.fish" "$SHELL_TARGET/fish/functions/c.fish"
   cp "$SHELL_SOURCE/claude-tmux.sh" "$SHELL_TARGET/bash/c.sh"

   # Generate Claude environment variables for bash/zsh
   cat > "$SHELL_TARGET/env.sh" << 'EOF'
   ```

# Claude Code environment variables

# Source this file in your shell profile (.bashrc, .zshrc, etc.)

# Enable MCP tool search in Claude Code

export ENABLE_TOOL_SEARCH="true"

# Enable LSP tools in Claude Code

export ENABLE_LSP_TOOLS="1"
EOF

# Generate Claude environment variables for fish

cat > "$SHELL_TARGET/fish/conf.d/claude-env.fish" << 'EOF'

# Claude Code environment variables

# This file is auto-sourced by fish from conf.d/

# Enable MCP tool search in Claude Code

set -gx ENABLE_TOOL_SEARCH "true"

# Enable LSP tools in Claude Code

set -gx ENABLE_LSP_TOOLS "1"
EOF

````

3. **Show changes:**
```bash
cd ~/Dropbox/Projects/Iniciador/ai-dev
git status
git diff --stat
````

4. **If there are changes, ask user for commit message and commit:**

   ```bash
   git add -A
   git commit -m "<user-provided message>"
   git push
   ```

5. **Report completion with summary of synced files.**
