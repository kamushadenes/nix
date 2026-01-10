# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nix flake configuration managing multiple Darwin (macOS) and NixOS systems with home-manager for user-level configuration. It uses agenix for secrets management with age encryption.

**Machines:**

- Darwin: `studio`, `macbook-m3-pro`, `w-henrique` (all aarch64-darwin)
- NixOS: x86_64-linux

## Commands

```bash
# Rebuild current system (preferred - includes --impure automatically)
# WARNING: MUST be run using the tmux MCP (start a fish shell, then inside that shell run rebuild)
rebuild

# Darwin rebuild via nh (--impure required for private submodule)
nh darwin switch --impure

# NixOS rebuild
sudo nixos-rebuild switch --flake ~/.config/nix/config/ --impure

# Direct darwin-rebuild
darwin-rebuild switch --flake ~/.config/nix/config/ --impure
```

## Architecture

```
flake.nix              # Entry point - defines inputs and machine configurations
├── darwin.nix         # Darwin system-level config
├── nixos.nix          # NixOS system-level config
├── home.nix           # Home-manager base config
│
├── shared/            # Cross-platform utilities
│   ├── helpers.nix    # Helper functions (globalVariables, mkEmail, git/fish helpers)
│   ├── build.nix      # Distributed build config (3 machines via ssh-ng)
│   ├── cache.nix      # Nix substituters and cache config
│   ├── packages.nix   # Custom package definitions
│   └── themes.nix     # Theme definitions
│
├── darwin/            # Darwin-specific modules (brew, dock, fonts, settings, etc.)
├── nixos/             # NixOS-specific modules (hardware, display, network, etc.)
│
├── home/
│   ├── common/        # Cross-platform home-manager modules
│   │   ├── ai/        # AI agents (claude-code, codex-cli, gemini-cli, orchestrator)
│   │   ├── core/      # git, ssh, nix, agenix, fonts
│   │   ├── dev/       # go, node, python, java, clang, clojure, android, embedded
│   │   ├── editors/   # nvim, emacs, vscode
│   │   ├── infra/     # cloud, docker, kubernetes, terraform
│   │   ├── media/     # media tools
│   │   ├── security/  # gpg, security tools
│   │   ├── shell/     # fish, bash, starship, kitty, ghostty
│   │   └── utils/     # aichat, miscellaneous utilities
│   ├── macos/         # macOS-specific (aerospace, bettertouchtool, sketchybar)
│   └── linux/         # Linux-specific (display, systemd)
│
└── private/           # Git submodule with encrypted secrets (symlinked from other modules)
```

## Key Patterns

**Module specialArgs:** Each configuration receives `machine`, `shared`, `pkgs-unstable`, `inputs`, `platform`, and `private` parameters for per-machine customization.

**Helpers (`shared/helpers.nix`):**

- `globalVariables.base` - Environment variables (EDITOR, DOOMDIR, NH_FLAKE)
- `globalVariables.launchctl` / `globalVariables.shell` - Platform-specific variable exports
- `mkConditionalGithubIncludes` - Git config per GitHub organization
- `mkAgenixPathSubst` - Secrets path substitution

**Secrets:** Age-encrypted files in `private/` submodule, identity at `~/.age/age.pem`. Secrets mount to temp directories (DARWIN_USER_TEMP_DIR or XDG_RUNTIME_DIR).

**Distributed builds:** Three machines share builds via ssh-ng protocol with custom cache at `ncps.hyades.io:8501`.

## Important: Git and Nix Flakes

**New files must be committed before Nix can see them.** Nix flakes only evaluate files tracked by git. When adding new files:

1. Stage and commit new files before running `nix flake check` or `rebuild`
2. Modified existing files work without committing
3. The `private/` submodule requires separate commits - commit there first, then update the submodule reference in the main repo

## Private Submodule Access

The `private/` directory is a git submodule. Due to nix flakes not including submodule contents when copying to the nix store, we use `builtins.fetchGit` with `submodules = true` to access private files.

**Key Points:**

- The `private` variable is passed through `specialArgs` to all modules
- Modules must add `private` to their function parameters: `{ config, pkgs, private, ... }:`
- Reference private files using `"${private}/relative/path"` (NOT symlinks like `./resources/...`)
- Rebuilds require `--impure` flag (the `rebuild` alias handles this)

**Example - Referencing a private secret file:**

```nix
{
  config,
  pkgs,
  private,  # Add this parameter
  ...
}:
{
  age.secrets = {
    "my-secret" = {
      file = "${private}/path/to/my-secret.age";  # Use private variable
      path = "${config.home.homeDirectory}/.secrets/my-secret";
    };
  };
}
```

**When adding new private resources:**

1. Add and commit the file in the `private/` submodule
2. Add `private` to the module's function parameters
3. Use `"${private}/path/from/private/root"` to reference the file
4. Commit the submodule reference update in the main repo

## Conventions

- Modules are self-contained and grouped by functionality
- Static files go in `resources/` subdirectories within their module
- Private/sensitive configs use the `private` variable (NOT symlinks) - see "Private Submodule Access" section
- Uses Lix (alternative Nix implementation) from stable package sets
- Primary shell is Fish; primary editor is Neovim (unstable channel)

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
