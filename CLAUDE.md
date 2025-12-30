# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nix flake configuration managing multiple Darwin (macOS) and NixOS systems with home-manager for user-level configuration. It uses agenix for secrets management with age encryption.

**Machines:**
- Darwin: `studio`, `macbook-m3-pro`, `w-henrique` (all aarch64-darwin)
- NixOS: x86_64-linux

## Commands

```bash
# Rebuild current system (preferred)
rebuild

# Darwin rebuild via nh
export NH_FLAKE="$HOME/.config/nix/config/?submodules=1"
nh darwin switch -H $(hostname -s | sed s"/.local//g")

# NixOS rebuild
sudo nixos-rebuild switch --flake ~/.config/nix/config/

# Direct darwin-rebuild
darwin-rebuild switch --flake ~/.config/nix/config/
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
│   │   ├── core/      # git, ssh, nix, agenix, fonts
│   │   ├── shell/     # fish, bash, starship, kitty, ghostty
│   │   ├── dev/       # go, node, python, java, clang, clojure
│   │   ├── editors/   # nvim, emacs, vscode
│   │   ├── infra/     # cloud, docker, kubernetes, terraform
│   │   └── security/  # gpg, security tools
│   ├── macos/         # macOS-specific (aerospace, bettertouchtool, sketchybar)
│   └── linux/         # Linux-specific (display, systemd)
│
└── private/           # Git submodule with encrypted secrets (symlinked from other modules)
```

## Key Patterns

**Module specialArgs:** Each configuration receives `machine`, `shared`, `pkgs-unstable`, `inputs`, and `platform` parameters for per-machine customization.

**Helpers (`shared/helpers.nix`):**
- `globalVariables.base` - Environment variables (EDITOR, DOOMDIR, NH_FLAKE)
- `globalVariables.launchctl` / `globalVariables.shell` - Platform-specific variable exports
- `mkConditionalGithubIncludes` - Git config per GitHub organization
- `mkAgenixPathSubst` - Secrets path substitution

**Secrets:** Age-encrypted files in `private/` submodule, identity at `~/.age/age.pem`. Secrets mount to temp directories (DARWIN_USER_TEMP_DIR or XDG_RUNTIME_DIR).

**Distributed builds:** Three machines share builds via ssh-ng protocol with custom cache at `ncps.hyades.io:8501`.

## Conventions

- Modules are self-contained and grouped by functionality
- Static files go in `resources/` subdirectories within their module
- Private/sensitive configs symlink from `private/` submodule
- Uses Lix (alternative Nix implementation) from stable package sets
- Primary shell is Fish; primary editor is Neovim (unstable channel)
