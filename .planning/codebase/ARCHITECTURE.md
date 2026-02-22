# Architecture

**Analysis Date:** 2026-02-21

## Pattern Overview

**Overall:** Multi-platform Nix flake with role-based composition and layered module system

**Key Characteristics:**
- Declarative system and user configuration via Nix flake + home-manager
- Three-tier role system (workstation, headless, minimal) controls module inclusion
- Platform abstraction separates Darwin (macOS) and NixOS (Linux) concerns
- Secrets management via agenix with age encryption (private git submodule)
- Machine definitions use factory helpers (`mkDarwinHost`, `mkNixosHost`, `mkProxmoxHost`) for consistent specialArgs
- Proxmox LXC containers use ephemeral root with configurable persistence via bind mounts

## Layers

**Flake Entry Point:**
- Purpose: Defines all machine configurations, inputs, and factory helpers
- Location: `flake.nix`
- Contains: `mkDarwinHost`, `mkNixosHost`, `mkProxmoxHost`, `mkDaemonLXCs` factory functions; machine declarations; Proxmox image builders
- Depends on: nixpkgs, nix-darwin, home-manager, agenix, claudebox, nix-moltbot, nixos-generators
- Used by: `rebuild` command to build/deploy any machine

**System Layer (Darwin):**
- Purpose: macOS system-level configuration (Homebrew, dock, settings, fonts, security)
- Location: `darwin.nix` (aggregator) + `darwin/*.nix` (individual modules)
- Contains: 24 domain-specific modules (brew, dock, settings, security, etc.)
- Depends on: `shared/build.nix`, `shared/cache.nix`, `shared/packages.nix`, `shared/overlays.nix`
- Used by: All Darwin machine configurations

**System Layer (NixOS):**
- Purpose: NixOS system-level configuration (security, SSH, fonts, desktop environments)
- Location: `nixos.nix` (aggregator) + `nixos/*.nix` (individual modules)
- Contains: Role-conditional module loading - core modules always, GUI modules only for workstation
- Depends on: `shared/build.nix`, `shared/cache.nix`, hardware configs, machine configs
- Used by: All NixOS machine configurations

**Hardware Layer:**
- Purpose: Machine-specific hardware configuration (LXC container settings, disk layout, networking)
- Location: `nixos/hardware/*.nix`
- Contains: One file per machine - imports Proxmox LXC module, sets hostname, imports machine config
- Depends on: `nixos/machines/*.nix` (service configs), `nixpkgs/virtualisation/proxmox-lxc.nix`
- Used by: `mkNixosHost` and `mkProxmoxHost` via the `hardware` parameter

**Machine Service Layer:**
- Purpose: Service-specific configuration for each deployed machine (systemd units, service configs)
- Location: `nixos/machines/*.nix`
- Contains: Service definitions (atuin, cloudflared, haos, mqtt, zigbee2mqtt, etc.)
- Depends on: Private secrets via agenix, system packages
- Used by: Hardware configs (imported by hardware files)

**Home-Manager Layer:**
- Purpose: User-level configuration (shells, editors, dev tools, AI tools)
- Location: `home.nix` (entry point) + `home/common/**/*.nix` (cross-platform) + `home/macos/*.nix` + `home/linux/*.nix`
- Contains: Role-composed module sets via `shared/roles.nix`
- Depends on: `shared/helpers.nix`, `shared/shell-common.nix`, `shared/themes.nix`, `shared/packages.nix`, `shared/fish-plugins.nix`
- Used by: All machine configurations (via home-manager integration in flake.nix)

**Shared Utilities Layer:**
- Purpose: Cross-platform helpers, theme definitions, custom packages, shell functions
- Location: `shared/*.nix` + `shared/resources/`
- Contains: `helpers.nix` (global variables, shell helpers, agenix helpers), `roles.nix` (module composition), `shell-common.nix` (shared shell config), `themes.nix` (Catppuccin themes), `packages.nix` (custom package definitions), `overlays.nix` (Lix overlay)
- Depends on: pkgs, lib, config
- Used by: Both system layers and home-manager layer

**Private/Secrets Layer:**
- Purpose: Encrypted secrets, private configs (network, SSH, API keys)
- Location: `private/` (git submodule, fetched via `builtins.fetchGit` with `--impure`)
- Contains: Age-encrypted secrets, private network configs, SSH configs
- Depends on: `~/.age/age.pem` identity file for decryption
- Used by: All layers via `private` specialArg

## Data Flow

**Machine Build Flow:**

1. `flake.nix` defines machine via `mkDarwinHost`/`mkNixosHost`/`mkProxmoxHost` with `machine`, `role`, `hardware` params
2. Factory function creates `specialArgs`: `{ inputs, machine, shared, private, role, platform, pkgs-unstable, claudebox }`
3. System modules loaded: `darwin.nix` or `nixos.nix` (with role-conditional imports)
4. Home-manager modules loaded: `home.nix` imports `shared/roles.nix` which calls `mkRoleModules { role, platform }` to compose the right set of home-manager modules
5. `specialArgs` plus `_module.args` (helpers, packages, shellCommon, themes, fishPlugins) become available to all modules

**specialArgs Flow:**
```
flake.nix (mkDarwinHost/mkNixosHost)
  ├─> specialArgs: { inputs, machine, shared, private, role, platform, pkgs-unstable, claudebox }
  ├─> System modules receive specialArgs directly
  └─> home-manager.extraSpecialArgs: same set (minus hardware)
       └─> home.nix receives them
            ├─> Creates _module.args: { helpers, packages, shellCommon, themes, fishPlugins, pkgs-unstable }
            └─> All home-manager modules receive both specialArgs and _module.args
```

**Role Composition Flow:**

1. `home.nix` imports `shared/roles.nix` with `{ lib, private }`
2. `roles.mkRoleModules { role, platform }` returns a list of module paths
3. Module groups are composed additively:
   - `workstation` = base + ai + dev + editors + infra + utils + sync + media + guiShell + platform-specific
   - `headless` = base + ai + dev + editors + infra + utils + sync + platform-specific (no GUI)
   - `minimal` = coreMinimal + shellMinimal + platform-specific (no dev tools)
4. `nixos.nix` also uses role to conditionally import system modules (GUI only for workstation)

**Secrets Flow:**

1. `private/` submodule contains `.age` encrypted files
2. `builtins.fetchGit` with `submodules = true` and `--impure` flag fetches private content
3. `private` variable passed through specialArgs to all modules
4. Modules reference secrets: `age.secrets."name".file = "${private}/path/to/secret.age"`
5. At activation, agenix decrypts to tmpdir using `~/.age/age.pem` identity
6. `helpers.mkAgenixPathSubst` converts decrypted paths for shell config files

**State Management:**
- System state: Nix store (immutable) + `/nix/persist` (for Proxmox LXCs with ephemeral root)
- User state: Home directory managed by home-manager with `backupFileExtension = "hm.bkp"`
- Proxmox persistence: Bind mounts from `/nix/persist` for selected paths (configured via `extraPersistPaths`)

## Key Abstractions

**Factory Helpers (`mkDarwinHost`, `mkNixosHost`, `mkProxmoxHost`):**
- Purpose: Standardize machine configuration creation with consistent specialArgs
- Location: `flake.nix` (lines 75-148)
- Pattern: Each takes `{ machine, role, ... }` and produces a full system configuration

**mkDaemonLXCs:**
- Purpose: Generate multiple LXC configs for daemon services that run on all Proxmox nodes
- Location: `flake.nix` (lines 152-160)
- Pattern: Takes `{ name, hardware }`, generates `name-pve1`, `name-pve2`, `name-pve3` configs
- Examples: `cloudflared-pve1`, `cloudflared-pve2`, `cloudflared-pve3`; `tailscale-pve1`, etc.

**Role System (`shared/roles.nix`):**
- Purpose: Compose home-manager module sets based on machine role
- Location: `shared/roles.nix`
- Pattern: Defines module groups (base, ai, dev, editors, etc.) and composes them into role-specific lists
- Roles: `workstation` (full GUI), `headless` (CLI dev), `minimal` (shell only for containers)

**helpers (`shared/helpers.nix`):**
- Purpose: Shared utility functions used by multiple modules
- Location: `shared/helpers.nix`
- Key exports: `globalVariables`, `shellIntegrations`, `theme`, `mkAgenixPathSubst`, `mkConditionalGithubIncludes`, `applySubst`
- Pattern: Imported in `home.nix` and passed via `_module.args`

**shellCommon (`shared/shell-common.nix`):**
- Purpose: Unified shell configuration across fish, bash, and zsh
- Location: `shared/shell-common.nix` + `shared/resources/shell/`
- Pattern: Reads script files from `resources/shell/`, provides separate fish and bash/zsh variants, applies template substitutions for Nix store paths
- Key exports: `aliases`, `fish.functions`, `bashZsh.functions`, `standaloneScripts`

**Proxmox Persistence (`nixos/proxmox/persistence.nix`):**
- Purpose: Configurable bind mounts from `/nix/persist` for LXC ephemeral root
- Location: `nixos/proxmox/persistence.nix`
- Pattern: Defines `proxmox.persistence.extraPaths` option, generates `fileSystems` entries and a systemd oneshot service to create directories before mounts

## Entry Points

**`flake.nix`:**
- Location: `flake.nix`
- Triggers: `rebuild` command, `nix build`, `darwin-rebuild switch`, `nixos-rebuild switch`
- Responsibilities: Define all inputs, machine configurations, specialArgs, Proxmox image builders

**`darwin.nix`:**
- Location: `darwin.nix`
- Triggers: Imported by `darwinModules` in `flake.nix`
- Responsibilities: Aggregate all Darwin system modules, configure Lix, linux-builder VM, overlays

**`nixos.nix`:**
- Location: `nixos.nix`
- Triggers: Imported by `nixosModules` in `flake.nix`
- Responsibilities: Aggregate NixOS system modules with role-conditional loading, configure Lix, overlays

**`home.nix`:**
- Location: `home.nix`
- Triggers: Imported as `home-manager.users.kamushadenes` in `flake.nix`
- Responsibilities: Set up `_module.args`, import role-composed modules, configure activation scripts

**`rebuild` (deploy.py):**
- Location: `shared/resources/deploy.py` (installed as `rebuild` standalone script)
- Triggers: User runs `rebuild [target]` from any shell
- Responsibilities: Local rebuild, remote deployment via SSH, parallel execution, tag-based filtering, Proxmox image building

## Error Handling

**Strategy:** Fail-fast with Nix evaluation errors; graceful degradation via role-based module exclusion

**Patterns:**
- Role conditionals prevent module loading on incompatible machines (e.g., no GUI on headless)
- `lib.mkForce` used to override conflicting defaults from imported modules
- `lib.mkDefault` allows downstream overrides of sensible defaults
- `lib.mkIf` used extensively for platform-conditional config (Darwin vs Linux)
- Proxmox persistence creates directories before mount attempts via systemd ordering

## Cross-Cutting Concerns

**Platform Abstraction:**
- `platform` specialArg carries the system string (e.g., `aarch64-darwin`, `x86_64-linux`)
- `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux` used in home-manager modules
- `roles.nix` uses platform to include platform-specific modules (macos, linuxDesktop, linuxCli)
- Separate system layers (`darwin.nix` vs `nixos.nix`) handle OS-level differences

**Theming:** Catppuccin Macchiato applied consistently via `shared/themes.nix` and `helpers.theme` with pre-computed naming variants

**Shell Configuration:** Three-shell support (fish, bash, zsh) via `shared/shell-common.nix` with separate script files per shell type due to syntax incompatibilities

**Package Channels:** Primary packages from stable nixpkgs; `pkgs-unstable` available for bleeding-edge tools (nh, neovim, etc.)

**Nix Implementation:** Uses Lix (alternative Nix implementation) via overlay in `shared/overlays.nix`, configured in both `darwin.nix` and `nixos.nix`

---

*Architecture analysis: 2026-02-21*
