# Codebase Structure

**Analysis Date:** 2026-02-21

## Directory Layout

```
config/
├── flake.nix              # Flake entry point - inputs, machine definitions, factory helpers
├── flake.lock             # Pinned input versions
├── darwin.nix             # Darwin system-level aggregator (imports darwin/*.nix)
├── nixos.nix              # NixOS system-level aggregator (imports nixos/*.nix, role-conditional)
├── home.nix               # Home-manager entry for kamushadenes (role composition)
├── home_root.nix          # Minimal home-manager for Darwin root (SSH config only)
├── home_root_nixos.nix    # Home-manager for NixOS root (same shell env as kamushadenes)
├── home_other.nix         # Home-manager for shared machine users (yjrodrigues)
├── AGENTS.md              # Project instructions for Claude Code
├── CLAUDE.md              # Points to AGENTS.md
├── README.md              # Project readme
│
├── shared/                # Cross-platform utilities and shared config
│   ├── helpers.nix        # Global variables, shell helpers, agenix path helpers, theme config
│   ├── roles.nix          # Role-based module composition (workstation/headless/minimal)
│   ├── shell-common.nix   # Shared shell functions for fish/bash/zsh
│   ├── fish-plugins.nix   # Fish plugin definitions (fetchFromGitHub)
│   ├── build.nix          # Distributed build machine configuration
│   ├── cache.nix          # Nix binary cache substituters (ncps, cachix)
│   ├── packages.nix       # Custom package definitions (lazyworktree, worktrunk, ccusage, etc.)
│   ├── overlays.nix       # Nixpkgs overlays (Lix packages)
│   ├── themes.nix         # Catppuccin theme assets (bat, btop, delta, fzf, k9s, starship, yazi)
│   └── resources/
│       ├── deploy.py      # Rebuild/deploy script (installed as `rebuild` command)
│       └── shell/         # Shell script files (one per function, per shell type)
│           ├── mkcd.sh / mkcd.fish
│           ├── ca.sh / ca.fish          # tmux session attach
│           ├── claude-tmux.sh           # Standalone 'c' command
│           ├── rga-fzf.sh / rga-fzf.fish
│           ├── flushdns.sh              # Cross-shell compatible
│           ├── help.sh / help.fish
│           └── add-go-build-tags.fish   # Fish-only
│
├── darwin/                # Darwin system modules (imported by darwin.nix)
│   ├── activation.nix     # Post-activation scripts
│   ├── brew.nix           # Homebrew package management
│   ├── browser.nix        # Browser packages
│   ├── db.nix             # Database tools
│   ├── dev.nix            # Development packages
│   ├── dock.nix           # macOS Dock configuration
│   ├── dropbox.nix        # Dropbox
│   ├── finance.nix        # Finance apps
│   ├── fonts.nix          # System fonts
│   ├── imaging.nix        # Imaging tools
│   ├── ipfs.nix           # IPFS
│   ├── login.nix          # Login items
│   ├── mas.nix            # Mac App Store apps
│   ├── media.nix          # Media apps
│   ├── meeting.nix        # Meeting apps
│   ├── nix.nix            # Nix-specific Darwin config
│   ├── security.nix       # Security configuration
│   ├── setapp.nix         # Setapp subscriptions
│   ├── settings.nix       # macOS system preferences
│   ├── sharing.nix        # Sharing preferences
│   ├── shells.nix         # Shell registration
│   ├── tiling.nix         # Window management
│   ├── users.nix          # User account config
│   └── utils.nix          # Utility packages
│
├── nixos/                 # NixOS system modules and machine configs
│   ├── audio.nix          # Audio (workstation only)
│   ├── browser.nix        # Browser (workstation only)
│   ├── dev.nix            # Dev tools (workstation only)
│   ├── display_gnome.nix  # GNOME desktop (workstation only)
│   ├── display_sway.nix   # Sway WM (workstation only)
│   ├── finance.nix        # Finance (workstation only)
│   ├── fonts.nix          # Fonts (workstation only)
│   ├── ipfs.nix           # IPFS (workstation only)
│   ├── media.nix          # Media (workstation only)
│   ├── meeting.nix        # Meeting (workstation only)
│   ├── minimal.nix        # Minimal role SSH defaults
│   ├── nix.nix            # Nix configuration
│   ├── security.nix       # SSH hardening, fail2ban, firewall, kernel sysctl
│   ├── shells.nix         # Shell registration
│   ├── users.nix          # User accounts (kamushadenes)
│   ├── utils.nix          # Utilities (workstation only)
│   │
│   ├── hardware/          # Per-machine hardware configs
│   │   ├── nixos.nix      # Primary NixOS workstation
│   │   ├── aether.nix     # Headless server
│   │   ├── atuin.nix      # Atuin LXC
│   │   ├── mqtt.nix       # MQTT LXC
│   │   ├── cloudflared-pve{1,2,3}.nix  # Cloudflared daemon LXCs
│   │   ├── tailscale-pve{1,2,3}.nix   # Tailscale daemon LXCs
│   │   ├── esphome.nix    # ESPHome LXC
│   │   ├── haos.nix       # Home Assistant LXC
│   │   ├── moltbot.nix    # Moltbot LXC
│   │   ├── ncps.nix       # Nix cache proxy LXC
│   │   ├── waha.nix       # WAHA WhatsApp LXC
│   │   └── zigbee2mqtt.nix # Zigbee2MQTT LXC
│   │
│   ├── machines/          # Per-machine service configs
│   │   ├── atuin.nix      # Atuin service config
│   │   ├── cloudflared.nix # Cloudflare tunnel service
│   │   ├── esphome.nix    # ESPHome service
│   │   ├── haos.nix       # Home Assistant service + custom components
│   │   ├── haos-custom-components.nix
│   │   ├── haos-lovelace-modules.nix
│   │   ├── moltbot.nix    # Moltbot AI gateway service
│   │   ├── mqtt.nix       # Mosquitto MQTT broker
│   │   ├── ncps.nix       # Nix cache proxy service
│   │   ├── tailscale.nix  # Tailscale subnet router
│   │   ├── waha.nix       # WhatsApp API service
│   │   ├── zigbee2mqtt.nix # Zigbee2MQTT service
│   │   └── resources/     # Static config files for services
│   │
│   ├── proxmox/           # Proxmox VM/LXC templates
│   │   ├── common.nix     # Shared Proxmox guest settings
│   │   ├── lxc.nix        # LXC container template (imports common.nix)
│   │   ├── vm.nix         # VM template (imports common.nix)
│   │   └── persistence.nix # Ephemeral root persistence module
│   │
│   └── install/           # Installation scripts
│
├── home/                  # Home-manager modules
│   ├── common/            # Cross-platform modules
│   │   ├── ai/            # AI agent tools
│   │   │   ├── claude-code.nix           # Claude Code config + sandbox
│   │   │   ├── claude-code-permissions.nix # Claude Code permissions
│   │   │   ├── claude-accounts.nix       # Multi-account detection
│   │   │   ├── codex-cli.nix             # OpenAI Codex CLI
│   │   │   ├── gemini-cli.nix            # Google Gemini CLI
│   │   │   ├── gsd.nix                   # GSD framework (slash commands)
│   │   │   ├── orchestrator.nix          # AI orchestration rules
│   │   │   └── mcp-servers.nix           # MCP server configs
│   │   ├── core/          # Core config (git, nix, agenix, fonts, network, SSH)
│   │   │   ├── agenix.nix
│   │   │   ├── fonts.nix
│   │   │   ├── git.nix
│   │   │   ├── network.nix
│   │   │   ├── nix.nix
│   │   │   └── nix-minimal.nix
│   │   ├── dev/           # Development tools
│   │   │   ├── android.nix, clang.nix, clojure.nix, dev.nix
│   │   │   ├── embedded.nix, go.nix, java.nix
│   │   │   ├── lazygit.nix, lazyworktree.nix
│   │   │   ├── node.nix, python.nix, worktrunk.nix
│   │   │   └── mcphub.nix
│   │   ├── editors/       # Editor configs
│   │   │   ├── emacs.nix
│   │   │   ├── nvim.nix
│   │   │   ├── vscode.nix (not in roles - manually included if needed)
│   │   │   └── resources/   # Editor resource files
│   │   ├── infra/         # Infrastructure tools
│   │   │   ├── cloud.nix, db.nix, docker.nix, iac.nix, kubernetes.nix
│   │   ├── media/         # Media tools (workstation only)
│   │   │   └── media.nix
│   │   ├── security/      # Security tools
│   │   │   ├── gpg.nix
│   │   │   └── tools.nix
│   │   ├── shell/         # Shell configuration
│   │   │   ├── fish.nix, bash.nix, zsh.nix
│   │   │   ├── starship.nix, tmux.nix
│   │   │   ├── misc.nix (full CLI tools), misc-minimal.nix (essential only)
│   │   │   ├── ghostty.nix, kitty.nix (GUI terminals, workstation only)
│   │   ├── sync/          # File synchronization
│   │   │   └── mutagen.nix
│   │   └── utils/         # Utilities
│   │       ├── aichat.nix, clipboard.nix, utils.nix
│   │
│   ├── macos/             # macOS-only home-manager modules (workstation + darwin)
│   │   ├── aerospace.nix       # AeroSpace tiling WM
│   │   ├── bettertouchtool.nix # BTT presets
│   │   ├── sketchybar.nix      # Status bar
│   │   └── resources/          # BTT presets, sketchybar scripts
│   │
│   └── linux/             # Linux-only home-manager modules
│       ├── display.nix    # X11/Wayland display config
│       ├── security.nix   # Linux security tools
│       ├── shell.nix      # Linux shell specifics
│       └── systemd.nix    # Systemd user services
│
├── private/               # Git submodule (encrypted secrets)
│   ├── darwin/network.nix # Private Darwin network config
│   ├── nixos/network.nix  # Private NixOS network config
│   ├── nixos/secrets/     # Age-encrypted secret files
│   ├── nixos/lxc-management.nix # LXC management secrets
│   ├── nixos/machines/resources/ # Private machine resources
│   ├── home/common/core/ssh.nix  # Private SSH config
│   ├── home/root/ssh.nix  # Root SSH config
│   ├── nodes.json         # Node definitions for deploy.py
│   └── cache-priv-key.pem.age   # Encrypted Nix cache signing key
│
├── scripts/               # Utility scripts
│   ├── lxc-add-machine    # Register new LXC machine in secrets
│   └── pve-sysctl-setup.sh # Proxmox host sysctl configuration
│
└── actions/               # direnv-triggered actions
    └── rebuild/
        └── .envrc
```

## Directory Purposes

**`shared/`:**
- Purpose: Cross-platform code shared by both Darwin and NixOS system configs and home-manager
- Contains: Helper functions, role composition, shell configuration, themes, custom packages, overlays
- Key files: `helpers.nix` (most-imported utility module), `roles.nix` (controls what gets installed per role), `shell-common.nix` (unified shell config)

**`darwin/`:**
- Purpose: macOS system-level modules imported by `darwin.nix`
- Contains: One `.nix` file per domain (brew, dock, fonts, security, settings, etc.)
- Key files: `settings.nix` (macOS defaults), `brew.nix` (Homebrew casks/formulae), `security.nix` (1Password, keychain)

**`nixos/`:**
- Purpose: NixOS system-level modules plus hardware/machine/Proxmox configs
- Contains: System modules, per-machine hardware configs, per-machine service configs, Proxmox templates
- Key files: `security.nix` (SSH hardening, fail2ban, firewall), `minimal.nix` (SSH defaults for LXCs)

**`nixos/hardware/`:**
- Purpose: One file per machine defining hardware-level config (LXC container type, hostname, platform)
- Contains: Imports Proxmox LXC module + machine service config
- Pattern: `hardware/*.nix` imports `machines/*.nix` (hardware -> service config relationship)

**`nixos/machines/`:**
- Purpose: Service-level configuration for each deployed machine
- Contains: Service definitions (systemd units, package configs, firewall rules)
- Pattern: Each file configures one service (atuin, cloudflared, mqtt, etc.)

**`nixos/proxmox/`:**
- Purpose: Proxmox guest templates and persistence management
- Contains: LXC/VM base templates, ephemeral root persistence module
- Key files: `persistence.nix` (bind mount management), `common.nix` (shared guest settings)

**`home/common/`:**
- Purpose: Cross-platform home-manager modules organized by domain
- Contains: Subdirectories for ai, core, dev, editors, infra, media, security, shell, sync, utils
- Pattern: Each `.nix` file is a self-contained module that can be included or excluded by role

**`home/macos/`:**
- Purpose: macOS-only home-manager modules (window management, status bar)
- Contains: AeroSpace config, BetterTouchTool presets, Sketchybar

**`home/linux/`:**
- Purpose: Linux-only home-manager modules (display, systemd services)
- Contains: X11/Wayland config, systemd user service environment variables

**`private/`:**
- Purpose: Git submodule with encrypted secrets and private configurations
- Contains: Age-encrypted secrets, private network configs, SSH configs, cache signing key
- Generated: No (manually maintained, requires separate commits)
- Committed: Yes (as git submodule reference)

## Key File Locations

**Entry Points:**
- `flake.nix`: Top-level entry - all machine definitions and inputs
- `darwin.nix`: Darwin system aggregator
- `nixos.nix`: NixOS system aggregator (with role conditionals)
- `home.nix`: Home-manager entry for primary user (kamushadenes)

**Configuration:**
- `shared/roles.nix`: Role-to-module mapping (controls what each machine type gets)
- `shared/helpers.nix`: Global variables, utility functions used everywhere
- `shared/cache.nix`: Binary cache configuration
- `shared/build.nix`: Distributed build machine settings

**Core Logic:**
- `shared/shell-common.nix`: Shell function definitions and alias management
- `shared/resources/deploy.py`: Deployment script (rebuild command)
- `nixos/proxmox/persistence.nix`: Ephemeral root persistence management

**Machine Configuration:**
- `nixos/hardware/<machine>.nix`: Hardware-level config for each NixOS/LXC machine
- `nixos/machines/<machine>.nix`: Service-level config for each machine

## Naming Conventions

**Files:**
- Nix modules: `lowercase-hyphenated.nix` (e.g., `shell-common.nix`, `misc-minimal.nix`, `nix-minimal.nix`)
- Domain modules: single word `.nix` (e.g., `fonts.nix`, `security.nix`, `docker.nix`)
- Shell scripts: `function-name.sh` (bash/zsh) and `function-name.fish` (fish)
- Hardware configs: `<machine-name>.nix` matching the machine name in `flake.nix`
- Daemon LXC hardware: `<service>-<pve-node>.nix` (e.g., `cloudflared-pve1.nix`)

**Directories:**
- Lowercase, hyphenated where needed
- `resources/` subdirectories for static files within modules
- `common/` for cross-platform modules within `home/`

**Module Parameters:**
- Use `{ config, pkgs, lib, ... }:` standard parameter set
- Add `private` when accessing secrets: `{ config, pkgs, private, ... }:`
- Add `role` when role-conditional: `{ config, pkgs, role, ... }:`
- Additional args from `_module.args`: `helpers`, `shellCommon`, `themes`, `fishPlugins`, `packages`, `pkgs-unstable`

## Where to Add New Code

**New LXC Service:**
1. Service config: `nixos/machines/<name>.nix` - systemd service, packages, firewall rules
2. Hardware config: `nixos/hardware/<name>.nix` - import proxmox-lxc module + machine config, set hostname
3. Machine definition: Add `mkProxmoxHost` entry in `flake.nix` with `extraPersistPaths`
4. Secrets (if needed): Add age-encrypted files in `private/nixos/secrets/<name>/`

**New Daemon LXC (runs on all Proxmox nodes):**
1. Machine config: `nixos/machines/<name>.nix`
2. Hardware configs: `nixos/hardware/<name>-pve{1,2,3}.nix` (one per node)
3. Add `mkDaemonLXCs` entry in `flake.nix`

**New Darwin System Module:**
1. Create `darwin/<domain>.nix`
2. Add import to `darwin.nix` imports list

**New NixOS System Module:**
1. Create `nixos/<domain>.nix`
2. Add import to `nixos.nix` (inside `lib.optionals` for role-conditional loading)

**New Home-Manager Module (cross-platform):**
1. Create `home/common/<category>/<name>.nix`
2. Add module path to appropriate group(s) in `shared/roles.nix`

**New Home-Manager Module (platform-specific):**
1. Create `home/macos/<name>.nix` or `home/linux/<name>.nix`
2. Add to `macos`, `linuxDesktop`, or `linuxCli` group in `shared/roles.nix`

**New Shell Function:**
1. Create script files in `shared/resources/shell/`:
   - `<name>.sh` for bash/zsh
   - `<name>.fish` for fish (required if using fish-specific syntax)
2. Add to `bashScripts`/`fishScripts` in `shared/shell-common.nix`
3. Wire into `fish.functions` and `bashZsh.functions` sections

**New Standalone Script (PATH binary):**
1. Add script content to `standaloneScripts` in `shared/shell-common.nix`
2. Script is installed via `pkgs.writeScriptBin` in the shell modules that consume shellCommon

**New Custom Package:**
1. Add definition to `shared/packages.nix`
2. Reference in consuming module via `packages.<name>` (available via `_module.args`)

**New Secret:**
1. Encrypt file with `age -r <public-key> -o private/path/to/secret.age`
2. Reference in module: `age.secrets."name".file = "${private}/path/to/secret.age"`
3. Commit in private submodule first, then update submodule ref in main repo

**New Theme Asset:**
1. Add fetchFromGitHub to `shared/themes.nix`
2. Reference in consuming module via `themes.<name>`

## Special Directories

**`private/`:**
- Purpose: Encrypted secrets and private configurations
- Generated: No
- Committed: As git submodule reference (contents in separate private repo)
- Access: Via `builtins.fetchGit` with `submodules = true` (requires `--impure`)

**`.planning/`:**
- Purpose: GSD framework planning documents
- Generated: By Claude Code GSD commands
- Committed: Yes

**`.claude/`:**
- Purpose: Claude Code configuration (rules, settings)
- Generated: Partially (some managed by Nix, some manual)
- Committed: Yes

**`shared/resources/`:**
- Purpose: Static files consumed by Nix modules (shell scripts, deploy script)
- Generated: No
- Committed: Yes

**`nixos/machines/resources/`:**
- Purpose: Static config files for machine services (private resources in `private/`)
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-02-21*
