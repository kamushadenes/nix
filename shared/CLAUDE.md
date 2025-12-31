# Shared Module Guidelines

## Shell Functions (`shell-common.nix`)

This module provides shared shell configuration for fish, zsh, and bash. Functions are stored in script files with separate versions for fish and bash/zsh due to fundamental syntax differences.

### File Structure

```
shared/
├── shell-common.nix          # Main module - reads scripts and builds config
└── resources/shell/          # Script files (one per function, per shell type)
    ├── mkcd.sh               # Bash/Zsh version
    ├── mkcd.fish             # Fish version
    ├── rebuild.sh            # Bash/Zsh version (with template substitution)
    ├── rebuild.fish          # Fish version (with template substitution)
    ├── claude-tmux.sh        # Bash/Zsh version (c function)
    ├── claude-tmux.fish      # Fish version (c function)
    ├── ca.sh                 # Bash/Zsh version (attach to tmux session)
    ├── ca.fish               # Fish version (attach to tmux session)
    ├── rga-fzf.sh            # Bash/Zsh version
    ├── rga-fzf.fish          # Fish version
    ├── flushdns.sh           # Simple commands (works in all shells)
    ├── help.sh               # Bash/Zsh version
    ├── help.fish             # Fish version
    └── add-go-build-tags.fish  # Fish-only (no bash/zsh equivalent)
```

### Why Separate Versions Are Required

Fish has fundamentally different syntax from bash/zsh. **Cross-shell compatibility is NOT possible for most scripts.** Key incompatibilities:

| Feature | Bash/Zsh | Fish | Compatible? |
|---------|----------|------|-------------|
| Variable assignment | `var=value` | `set var value` | ❌ No |
| Positional arguments | `$1`, `$2` | `$argv[1]`, `$argv[2]` | ❌ No |
| If/then/fi | `if ...; then ... fi` | `if ... end` | ❌ No |
| Exit status | `$?` | `$status` | ❌ No |
| Command substitution | `$(cmd)` | `(cmd)` | ⚠️ Fish supports `$()` |
| Conditionals | `[[ ]]` or `test` | `test` only | ⚠️ Use `test` |
| Boolean operators | `&&` `||` | `&&` `||` or `and` `or` | ✅ Yes |
| Local variables | `local var=x` | `set -l var x` | ❌ No |

### Simple Commands (No Separate Version Needed)

Only the simplest scripts can be shared - those with just commands and no:
- Variable assignments
- Positional arguments
- Control flow (if/for/while)

**Example:** `flushdns.sh` works in all shells:
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Writing Fish Scripts

Use fish-native syntax:

```fish
# Variable assignment
set git_root (git rev-parse --show-toplevel 2>/dev/null || pwd)

# Positional arguments
mkdir -p $argv[1] && cd $argv[1]

# If/end blocks
if test -n "$TMUX"
  claude $argv
else
  tmux new-session -s "$session_name" "claude $argv"
end

# Exit status
if test $status -ne 0
  return 1
end
```

### Writing Bash/Zsh Scripts

Use standard bash syntax:

```bash
# Variable assignment
git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Positional arguments
mkdir -p "$1" && cd "$1"

# If/then/fi blocks
if test -n "$TMUX"; then
  claude "$@"
else
  tmux new-session -s "$session_name" "claude $*"
fi

# Exit status
if test $? -ne 0; then
  return 1
fi
```

### Template Substitutions

For dynamic values (Nix store paths, computed values), use `@placeholder@` syntax:

```bash
# In rebuild.sh
@ageBin@ -d -i "@ageIdentity@" "@cacheKeyAgePath@" > "@cacheKeyPath@"
```

Define substitutions in `shell-common.nix`:

```nix
rebuildSubst = {
  "@cacheKeyPath@" = cacheKeyPath;
  "@ageBin@" = "${pkgs.age}/bin/age";
};

scripts.rebuild = applySubst rebuildSubst (builtins.readFile "${resourcesDir}/rebuild.sh");
```

### Adding a New Function

1. Create script file in `resources/shell/`:
   - Use `.sh` extension for cross-shell compatible scripts
   - Use `.fish` extension only if fish-specific syntax is required

2. Add to `scripts` attrset in `shell-common.nix`:
   ```nix
   scripts = {
     myFunc = builtins.readFile "${resourcesDir}/my-func.sh";
   };
   ```

3. Reference in fish and bashZsh sections:
   ```nix
   fish.functions.my_func.body = scripts.myFunc;
   bashZsh.functions = ''
     my_func() { ${scripts.myFunc} }
   '';
   ```

4. For conditional functions (e.g., Darwin-only):
   ```nix
   (lib.mkIf pkgs.stdenv.isDarwin {
     flushdns.body = scripts.flushdns;
   })
   ```

### Module Usage

Shell modules receive `shellCommon` via `_module.args` in `home.nix`:

```nix
# In fish.nix, zsh.nix, or bash.nix
{ shellCommon, ... }:
{
  programs.fish.functions = shellCommon.fish.functions;
  programs.fish.shellAliases = shellCommon.aliases;

  programs.zsh.initExtra = shellCommon.bashZsh.functions;
  programs.zsh.shellAliases = shellCommon.aliases;
}
```
