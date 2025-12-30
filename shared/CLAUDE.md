# Shared Module Guidelines

## Shell Functions (`shell-common.nix`)

This module provides shared shell configuration for fish, zsh, and bash. Functions are stored in script files and used across all shells.

### File Structure

```
shared/
├── shell-common.nix          # Main module - reads scripts and builds config
└── resources/shell/          # Script files (one per function)
    ├── mkcd.sh               # Cross-shell compatible
    ├── rebuild.sh            # Cross-shell compatible (uses template substitution)
    ├── claude-tmux.sh        # Cross-shell compatible
    ├── rga-fzf.sh            # Cross-shell compatible
    ├── flushdns.sh           # Cross-shell compatible
    ├── help.sh               # Cross-shell compatible
    └── add-go-build-tags.fish  # Fish-only (uses fish-specific syntax)
```

### Writing Cross-Shell Compatible Scripts

Most scripts can work across fish, bash, and zsh by using POSIX-compatible syntax:

| Use This | NOT This | Reason |
|----------|----------|--------|
| `test -f file` | `[[ -f file ]]` | `[[ ]]` not supported in fish |
| `test -n "$VAR"` | `[[ -n "$VAR" ]]` | Same reason |
| `$(command)` | Both work | Fish supports `$()` |
| `$1`, `$2` | `$argv[1]` | Fish supports positional params |
| `$?` or `$status` | Either works | Fish uses `$status`, bash uses `$?` |
| `&&` and `||` | `and` / `or` | Fish supports both |
| No `local` keyword | `local var=x` | Fish doesn't support `local` |

**Example of cross-shell compatible script:**
```bash
# rebuild.sh - works in fish, bash, and zsh
if test -f "@cacheKeyAgePath@" && test ! -f "@cacheKeyPath@"; then
  echo "Decrypting..."
  if test $? -ne 0; then
    return 1
  fi
fi
```

### When Fish-Only is Required

Create a `.fish` file only when the function requires:

- Fish array syntax: `$argv[1..-2]`, `(count $argv)`
- Fish `set` command for variables: `set -l var value`
- Fish `for` loop with command substitution: `for x in (command)`

**Example:** `add-go-build-tags.fish` uses `$argv[1]` array slicing which has no POSIX equivalent.

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
