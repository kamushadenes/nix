# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nix flake configuration managing multiple Darwin (macOS) and NixOS systems with home-manager for user-level configuration. It uses agenix for secrets management with age encryption.

**Machines:**

- Darwin: `studio`, `macbook-m3-pro`, `w-henrique` (all aarch64-darwin)
- NixOS: `nixos`, `aether` (x86_64-linux)
- Proxmox LXCs: `atuin`, `mqtt`, `cloudflared` (x86_64-linux, minimal role)

**Proxmox Hosts:**
- `pve1`: 10.23.5.10 (SSH as root for LXC management via `pct` commands)

## Moltbot (AI Assistant Gateway)

Moltbot is deployed as a Proxmox LXC container providing AI assistant capabilities via Telegram.

**Configuration Files:**
- **NixOS config:** `nixos/machines/moltbot.nix` - systemd service, secrets, tmpfiles
- **Runtime config:** `private/nixos/machines/resources/moltbot/moltbot.json` - channels, agents, models (private)
- **Secrets:** `private/nixos/secrets/moltbot/*.age` - API keys, tokens

**Key Locations on LXC:**
- Config: `/var/lib/moltbot/.moltbot/moltbot.json`
- Workspace: `/var/lib/moltbot/workspace`
- Auth profiles: `/var/lib/moltbot/.moltbot/agents/main/agent/auth-profiles.json`

**Deployment:**
```bash
rebuild -vL moltbot  # Build locally and deploy to LXC
```

**Documentation:** https://docs.molt.bot/

## Commands

```bash
# Rebuild current system (preferred - includes --impure automatically)
rebuild

# Rebuild aether remotely (can run in parallel with local rebuild)
rebuild aether

# Both can be run in parallel using separate Bash tool calls

# Darwin rebuild via nh (--impure required for private submodule)
nh darwin switch --impure

# NixOS rebuild
sudo nixos-rebuild switch --flake ~/.config/nix/config/ --impure

# Direct darwin-rebuild
darwin-rebuild switch --flake ~/.config/nix/config/ --impure
```

**IMPORTANT: Cache timeout errors require rebuild retry.** If `rebuild` fails with:
```
error: unable to download 'http://ncps.hyades.io:8501/...': Connection timed out
```
This is NOT benign - the build was interrupted and packages may not be installed. Run `rebuild` again until it completes without cache errors.

**IMPORTANT: Use `-vL` flags for LXC deployments.** When deploying to Proxmox LXCs, always use both flags:
```bash
rebuild -vL cloudflared  # Build locally (-L), stream output (-v)
```
- `-v` / `--verbose`: Streams output in real-time (prevents timeouts)
- `-L` / `--local-build`: Builds locally and pushes to remote (faster, no need to copy age/ssh keys to LXC)

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
│   ├── roles.nix      # Role-based configuration (workstation, headless)
│   ├── shell-common.nix # Shared shell functions (fish, bash, zsh)
│   └── themes.nix     # Theme definitions
│
├── darwin/            # Darwin-specific modules (brew, dock, fonts, settings, etc.)
├── nixos/             # NixOS-specific modules (hardware, display, network, etc.)
│
├── home/
│   ├── common/        # Cross-platform home-manager modules
│   │   ├── ai/        # AI agents (claude-code, codex-cli, gemini-cli, orchestrator, mcp-servers)
│   │   ├── core/      # git, nix, agenix, fonts
│   │   ├── dev/       # go, node, python, java, clang, clojure, android, embedded, lazygit, worktrunk
│   │   ├── editors/   # nvim, emacs, vscode
│   │   ├── infra/     # cloud, docker, kubernetes, iac
│   │   ├── media/     # media tools
│   │   ├── security/  # gpg, security tools
│   │   ├── shell/     # fish, bash, zsh, starship, kitty, ghostty, tmux
│   │   ├── sync/      # mutagen file synchronization (hub-and-spoke with aether)
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

**File synchronization:** Uses Mutagen with hub-and-spoke topology. `aether` serves as the central hub, and spoke machines (Darwin and other NixOS) sync project folders bidirectionally. Managed via `home/common/sync/mutagen.nix`. Run `mutagen-setup` on spoke machines to create sync sessions.

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

## CRITICAL: Never Guess - Always Consult Documentation

**NEVER guess or assume configuration formats, API structures, or tool behaviors.** Always consult official documentation before implementing.

When working with tools or services:
1. **Find the documentation first** - Don't invent config formats
2. **Verify the expected format** - Check docs or existing working examples
3. **If docs are unavailable** - Ask the user before proceeding with assumptions

### Key Documentation URLs

- **Moltbot**: https://docs.molt.bot/ - AI assistant gateway (Telegram, Discord, etc.)
- **better-ccflare**: https://github.com/tombii/better-ccflare - Claude API proxy (fork of snipeship/ccflare)

## Cloudflare DNS Token (Global Secret)

A global Cloudflare DNS API token is stored at `private/nixos/secrets/cloudflare/cloudflare-dns-token.age` for Let's Encrypt ACME DNS-01 challenges. The env file format is `CLOUDFLARE_DNS_API_TOKEN=<token>`.

**Adding a new machine as consumer:**
1. Add the machine's SSH host key to `private/nixos/secrets/cloudflare/secrets.nix`
2. Re-encrypt: `cd private/nixos/secrets/cloudflare && agenix -r`
3. In the machine's nix config, reference it via `age.secrets` and `security.acme`

**ccflare LXC uses this** for `ccflare.hyades.io` TLS (native SSL via `SSL_KEY_PATH`/`SSL_CERT_PATH`). ACME certs persist at `/var/lib/acme`.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
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
