# Coding Conventions

**Analysis Date:** 2026-02-21

## Nix Module Structure

**Standard home-manager module pattern:**
```nix
{
  config,
  pkgs,
  lib,
  helpers,      # From shared/helpers.nix via _module.args
  shellCommon,  # From shared/shell-common.nix via _module.args
  themes,       # From shared/themes.nix via _module.args
  packages,     # From shared/packages.nix via _module.args
  ...
}:
{
  home.packages = with pkgs; [ ... ];
  programs.foo = {
    enable = true;
    # configuration...
  };
}
```

**Standard system module pattern (darwin/nixos):**
```nix
{
  config,
  pkgs,
  lib,
  platform,
  private,
  role,
  inputs,
  ...
}:
{
  imports = [ ... ];
  # system configuration...
}
```

**Available specialArgs (passed to all modules):**
- `inputs` - Flake inputs
- `machine` - Machine hostname (e.g., `"studio.hyades.io"`)
- `shared` - Whether machine is shared (boolean)
- `private` - Path to private submodule content
- `role` - One of: `"workstation"`, `"headless"`, `"minimal"`
- `platform` - System string (e.g., `"aarch64-darwin"`, `"x86_64-linux"`)
- `claudebox` - Claudebox package
- `pkgs-unstable` - Unstable nixpkgs channel

**Available _module.args (set in `home.nix`):**
- `helpers` - From `shared/helpers.nix`
- `packages` - From `shared/packages.nix`
- `shellCommon` - From `shared/shell-common.nix`
- `themes` - From `shared/themes.nix`
- `fishPlugins` - From `shared/fish-plugins.nix`
- `pkgs-unstable` - Unstable nixpkgs channel

## Naming Conventions

**Files:**
- Module files: lowercase with hyphens (e.g., `claude-code.nix`, `shell-common.nix`)
- Resource dirs: `resources/` within each module directory
- Minimal variants: suffix `-minimal` (e.g., `misc-minimal.nix`, `nix-minimal.nix`)
- Machine configs: `nixos/machines/<name>.nix` or `nixos/hardware/<name>.nix`

**Nix Attribute Names:**
- Use camelCase for let-binding variables (e.g., `resourcesDir`, `fishScripts`, `pathAdditions`)
- Use lowercase with hyphens for package names (e.g., `tdd-guard-go`, `godoc-mcp`)
- Use camelCase for helper functions (e.g., `mkDarwinHost`, `mkAgenixPathSubst`)
- Prefix factory functions with `mk` (e.g., `mkEmail`, `mkConditionalGithubIncludes`, `mkRoleModules`)

**Secret Names:**
- Agenix secrets use hyphen-separated names with a prefix: `"claude-github-pat"`, `"moltbot-telegram-token"`
- Secret files use `.age` extension in private submodule

**Placeholder Tokens:**
- Use `@UPPERCASE_WITH_UNDERSCORES@` format (e.g., `@GITHUB_PAT@`, `@cacheKeyPath@`)
- Template files use `.template` suffix (e.g., `mcp-servers.json.template`)

## Import Organization

**System-level modules (`darwin.nix`, `nixos.nix`):**
1. Shared modules (`shared/build.nix`, `shared/cache.nix`)
2. Platform-specific modules (`darwin/*.nix` or `nixos/*.nix`)
3. Private modules (`"${private}/darwin/network.nix"`)
4. Role-conditional modules via `lib.optionals`

**Home-manager entry point (`home.nix`):**
1. Import shared modules in `let` block
2. Set `_module.args` for downstream modules
3. Import role-based modules via `roles.mkRoleModules`
4. Import agenix home-manager module

**Within modules:**
- Import private files using `"${private}/relative/path"` (string interpolation, NOT symlinks)
- Use `let` bindings for local definitions, expose via attribute set

## Role-Based Module Composition

Defined in `shared/roles.nix`. Three roles control which modules are imported:

| Role | Purpose | Includes |
|------|---------|----------|
| `workstation` | Full GUI desktop | All modules + GUI shells + platform desktop |
| `headless` | CLI-only server | Base + AI + dev + editors + infra + utils + sync |
| `minimal` | Service containers | Core minimal + shell minimal + (Linux: systemd) |

Use `role` parameter in `flake.nix` host definitions:
```nix
mkDarwinHost { machine = "studio.hyades.io"; role = "workstation"; }
mkProxmoxHost { machine = "atuin"; role = "minimal"; }
```

## Configuration Patterns

**Shell integration helpers (from `shared/helpers.nix`):**
```nix
# Enable shell integrations for all configured shells
programs.broot = {
  enable = true;
} // helpers.shellIntegrations;

# Disable Fish integration (for evalcache programs)
programs.atuin = {
  enable = true;
} // helpers.shellIntegrationsNoFish;

# Bash/Zsh only (no fish option)
programs.direnv = {
  enable = true;
} // helpers.shellIntegrationsBashZsh;
```

**Theme references (from `shared/helpers.nix`):**
```nix
# Use pre-computed theme variant strings
helpers.theme.variants.underscore   # "catppuccin_macchiato" (for btop, starship)
helpers.theme.variants.hyphen       # "catppuccin-macchiato" (for ghostty, git)
helpers.theme.variants.titleSpace   # "Catppuccin Macchiato" (for bat)
helpers.theme.variants.titleHyphen  # "Catppuccin-Macchiato" (for kitty)
helpers.theme.variants.variantOnly  # "macchiato" (for yazi, starship TOML)
```

**Platform-conditional configuration:**
```nix
# In module definitions
home.packages = with pkgs;
  [ common-package ]
  ++ lib.optionals stdenv.isDarwin [ darwin-only-package ]
  ++ lib.optionals stdenv.isLinux [ linux-only-package ];

# In import lists
lib.optionals (!isServer) [ ./nixos/dev.nix ]

# In home-manager options
lib.mkIf pkgs.stdenv.isDarwin { ... }
```

**Unstable package usage:**
```nix
# Use pkgs-unstable for bleeding-edge packages
pkgs-unstable.gopls
pkgs-unstable.nh
pkgs-unstable.neovim-unwrapped
```

**Custom package definitions (inline in module):**
```nix
let
  myPackage = pkgs.buildGoModule rec {
    pname = "my-package";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub { ... };
    vendorHash = "...";
    meta = { ... };
  };
in
{
  home.packages = [ myPackage ];
}
```

**Shared custom packages (in `shared/packages.nix`):**
```nix
# Define in shared/packages.nix
myTool = pkgs.buildGoModule { ... };

# Use in modules via packages arg
{ packages, ... }:
{
  home.packages = [ packages.myTool ];
}
```

## Resource File Organization

Static files live in `resources/` subdirectories co-located with their module:

```
home/common/ai/resources/claude-code/
  ├── commands/       # Slash commands (.md files)
  ├── agents/         # Agent definitions (.md files)
  ├── rules/          # Rule files (auto-discovered)
  ├── memory/         # Global CLAUDE.md content
  ├── scripts/        # Hook scripts and utilities
  │   └── hooks/      # PreToolUse/, PostToolUse/, Stop/, etc.
  └── config/         # Tool configs (markdownlint.jsonc)

home/common/core/resources/git/
  ├── gitignore_global
  └── hooks/

home/common/editors/resources/lazyvim/
  ├── lua/            # Neovim config
  ├── init.lua
  └── lazy-lock.json

home/common/shell/resources/
  ├── *.sh            # Bash/Zsh scripts
  └── *.fish          # Fish scripts

home/macos/resources/
  ├── bettertouchtool/
  └── sketchybar/

shared/resources/
  ├── shell/          # Shared shell scripts
  └── deploy.py       # Rebuild deployment script
```

**Pattern:** Reference resources from modules using relative paths:
```nix
let
  resourcesDir = ./resources/claude-code;
in
{
  xdg.configFile."nvim/lua".source = ./resources/lazyvim/lua;
  home.file.".claude/hooks/Stop/post-lint.sh".source = "${resourcesDir}/scripts/hooks/Stop/post-lint.sh";
}
```

## Secrets Management (Agenix)

**Identity file:** `~/.age/age.pem` (configured in `home.nix` and `darwin.nix`)

**Secret declaration patterns:**

Home-manager level (in home modules):
```nix
age.secrets = {
  "secret-name" = {
    file = "${private}/path/to/secret.age";
    path = "${config.home.homeDirectory}/.secrets/secret-name";
  };
};
```

System level (in NixOS machine configs):
```nix
age.secrets = {
  "moltbot-telegram-token" = {
    file = "${private}/nixos/secrets/moltbot/telegram-bot-token.age";
    owner = "moltbot";
    group = "moltbot";
  };
};
```

**Template substitution pattern (for config files with secrets):**
1. Write template file with `@PLACEHOLDER@` tokens
2. Declare agenix secrets for each placeholder
3. Use `home.activation` script to copy template and substitute placeholders with decrypted values

Example from `claude-code.nix`:
```nix
# Template with placeholders
home.file.".claude/mcp-servers.json.template".text = templateContent;

# Activation script substitutes secrets
home.activation.claudeCodeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  run cp template working-file
  run ${lib.getExe pkgs.gnused} -i "s|@GITHUB_PAT@|$(cat ${secretPath})|g" working-file
'';
```

**Reusable secret helpers (from `home/common/ai/mcp-servers.nix`):**
- `mkAgenixSecrets` - Generate agenix secret declarations from placeholder list
- `mkSecretSubstitutions` - Generate placeholder-to-path mapping
- `mkActivationScript` - Generate activation script for secret substitution

## Shell Script Conventions

**Dual-version pattern:** Fish and Bash/Zsh require separate script files due to fundamental syntax differences. Place in `shared/resources/shell/`:
- `name.fish` - Fish version
- `name.sh` - Bash/Zsh version
- Simple commands (no variables, no control flow) can use a single `.sh` file for all shells

**Template substitution for scripts:**
```nix
# In shell-common.nix
deploySubst = {
  "@cacheKeyPath@" = cacheKeyPath;
  "@ageBin@" = "${pkgs.age}/bin/age";
};

scripts.rebuild = applySubst deploySubst (builtins.readFile ./resources/deploy.py);
```

**Standalone scripts (installed to PATH):**
```nix
home.packages = [
  (pkgs.writeScriptBin "rebuild" shellCommon.standaloneScripts.rebuild)
  (pkgs.writeScriptBin "c" shellCommon.standaloneScripts.c)
];
```

## Comment Style

**Module-level doc comments:** Block comment at top of file:
```nix
# Claude Code (claude.ai/code) configuration
#
# Uses the built-in home-manager programs.claude-code module for settings.
# MCP servers are managed separately to support secret substitution.
```

**Section headers in large modules:** Use hash-box separators:
```nix
  #############################################################################
  # Agenix Secrets
  #############################################################################
```

**In shared/helpers.nix:** Use boxed section headers:
```nix
  ########################################
  #                                      #
  # Global Variables                     #
  #                                      #
  ########################################
```

**Inline comments:** Explain "why" not "what":
```nix
# Cache homebrew init (evalcache avoids ~200ms startup penalty)
shellCommon.fish.homebrewInit

# Work around https://github.com/Homebrew/brew/issues/13219
HOMEBREW_SSH_CONFIG_PATH = "...";
```

## Module Design

**Self-contained:** Each module in `home/common/` is a complete unit managing one concern (e.g., `go.nix` handles Go compiler, tools, TDD guard, MCP servers).

**Conditional imports:** Use `lib.mkIf` for optional features within a module:
```nix
(lib.mkIf config.programs.bat.enable {
  cat = "bat -p";
  man = "batman";
})
```

**Merging configurations:** Use `lib.mkMerge` for combining multiple config sources:
```nix
programs.fish.functions = lib.mkMerge [
  shellCommon.fish.functions
  (lib.mkIf config.programs.starship.enable { ... })
];
```

**Private module references:** Always use the `private` variable, never symlinks:
```nix
# Correct
"${private}/darwin/network.nix"

# Wrong - do NOT use
./resources/network.nix  # symlink to private
```

## Formatting

**Tool:** `nixfmt` (enforced via lefthook pre-commit hook)
**Configuration:** `lefthook.yml` at repo root
**Run manually:** `nixfmt -v *.nix` or `nix fmt`

---

*Convention analysis: 2026-02-21*
