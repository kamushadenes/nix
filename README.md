# Nix Configuration

A Nix flake managing **26 systems** across macOS, NixOS, and Proxmox LXC
containers with home-manager for user-level configuration, agenix for secrets
management, and a role-based module composition system.

The `private` folder is a git submodule pointing to a private repo that contains
encrypted secrets. Modules access it via the `private` variable passed through
`specialArgs`, meaning the config won't work as-is for someone without access to
that private repo (hopefully no one but me).

Still, the config has some niceties so I thought it would be cool to share.
Enjoy!

## Table of Contents

- [Machine Inventory](#machine-inventory)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Applying Changes](#applying-changes)
- [Architecture](#architecture)
- [Role System](#role-system)
- [Available Commands](#available-commands)
- [Proxmox Infrastructure](#proxmox-infrastructure)
- [Key Patterns](#key-patterns)
- [Private Submodule](#private-submodule)
- [Troubleshooting](#troubleshooting)

## Machine Inventory

### Darwin (macOS) — aarch64-darwin

| Machine          | Role        | Shared |
| ---------------- | ----------- | ------ |
| `studio`         | workstation | no     |
| `macbook-m3-pro` | workstation | yes    |
| `w-henrique`     | workstation | no     |

### NixOS — x86_64-linux

| Machine  | Role        | Description                                         |
| -------- | ----------- | --------------------------------------------------- |
| `nixos`  | workstation | Full desktop NixOS                                  |
| `aether` | headless    | Dev environment with OpenChamber (web-based AI IDE) |

### Proxmox LXC Containers — x86_64-linux

**Singleton services** (1 instance):

| Machine       | Service                  | Purpose                                 | Persistence                            |
| ------------- | ------------------------ | --------------------------------------- | -------------------------------------- |
| `atuin`       | Atuin sync server        | Shell history sync (SQLite)             | `/var/lib/atuin`                       |
| `mqtt`        | Mosquitto                | MQTT broker for Home Assistant          | `/var/lib/mosquitto`                   |
| `zigbee2mqtt` | Zigbee2MQTT              | Zigbee device bridge to MQTT            | `/var/lib/zigbee2mqtt`                 |
| `esphome`     | ESPHome (Docker)         | ESP device firmware builder             | `/var/lib/esphome`, `/var/lib/docker`  |
| `ncps`        | Nix Cache Proxy (Docker) | Local Nix binary cache with NFS storage | `/var/lib/docker`, `/var/lib/acme`     |
| `waha`        | WAHA (Docker)            | WhatsApp HTTP API gateway               | `/var/lib/waha`, `/var/lib/docker`     |
| `haos`        | Home Assistant           | Home automation (native NixOS service)  | `/var/lib/hass`                        |
| `moltbot`     | Moltbot Gateway          | Telegram AI assistant                   | `/var/lib/moltbot`                     |
| `nanoclaw`    | NanoClaw (Docker)        | Personal AI agent for WhatsApp/Telegram | `/var/lib/nanoclaw`, `/var/lib/docker` |
| `prometheus`  | Prometheus               | Central metrics collection              | `/var/lib/prometheus2`                 |
| `grafana`     | Grafana                  | Monitoring dashboards                   | `/var/lib/grafana`                     |
| `influxdb`    | InfluxDB v2              | Time-series DB for Proxmox metrics      | `/var/lib/influxdb2`                   |
| `mutagen`     | Mutagen sync hub         | NFS mount hub for file synchronization  | (NFS mount only)                       |

**Daemon services** (replicated across pve1, pve2, pve3 for HA):

| Machine                    | Service              | Purpose                           | State                    |
| -------------------------- | -------------------- | --------------------------------- | ------------------------ |
| `cloudflared-pve{1,2,3}`   | Cloudflare Tunnel    | Secure tunnel connectors          | Stateless (shared token) |
| `tailscale-pve{1,2,3}`     | Tailscale            | VPN subnet router + exit node     | Per-node identity        |
| `prom-exporter-pve{1,2,3}` | node_exporter + IPMI | Hardware metrics per Proxmox host | Stateless                |

## Tech Stack

- **Nix implementation**: [Lix](https://lix.systems/) (stable)
- **Nix channels**: nixpkgs-25.11-darwin (stable), nixpkgs-unstable
- **System management**: [nix-darwin](https://github.com/LnL7/nix-darwin)
  (macOS), NixOS (Linux)
- **User configuration**:
  [home-manager](https://github.com/nix-community/home-manager) 25.11
- **Secrets**: [agenix](https://github.com/ryantm/agenix) (age encryption)
- **Image generation**:
  [nixos-generators](https://github.com/nix-community/nixos-generators) (Proxmox
  VM/LXC)
- **Binary cache**: [NCPS](https://ncps.hyades.io) (self-hosted) + cachix +
  cache.nixos.org
- **Theme**: Catppuccin Macchiato (applied globally across bat, btop, delta,
  fzf, k9s, starship, yazi, kitty, ghostty, tmux)
- **Primary shell**: Fish
- **Primary editor**: Neovim (LazyVim, unstable channel)
- **Formatting**: nixfmt (enforced via lefthook pre-commit hook)
- **Deployment**: Custom Python-based `rebuild` tool with parallel execution

## Prerequisites

- [Nix](https://nixos.org/download/) with flakes enabled
- `~/.age/age.pem` — Age encryption identity key
- `~/.ssh/keys/id_ed25519` — SSH key for private repo access
- Access to the `private` git submodule (kamushadenes/nix-private)

## Getting Started

### Initial Setup

```bash
# Create Nix config directory
mkdir -p ~/.config/nix

# Configure Nix with binary caches
cat > ~/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
substituters = https://ncps.hyades.io https://nix-community.cachix.org https://cache.nixos.org
trusted-public-keys = ncps.hyades.io:/02vviGNLGYhW28GFzmPFupnP6gZ4uDD4G3kRnXuutE= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
secret-key-files = /Users/kamushadenes/.config/nix/config/private/cache-priv-key.pem
EOF

# Clone the repo with submodules
git clone --recursive git@github.com:kamushadenes/nix.git ~/.config/nix/config/

# Decrypt the cache signing key (required for pushing to cache)
age -d -i ~/.age/age.pem ~/.config/nix/config/private/cache-priv-key.pem.age > ~/.config/nix/config/private/cache-priv-key.pem
chmod 600 ~/.config/nix/config/private/cache-priv-key.pem
```

> **Note:** The `rebuild` function will automatically decrypt the cache key if
> it's missing, so manual decryption is only needed for the initial bootstrap.

### Remote Machine Setup

For setting up a new machine, there's a helper script that automates the entire
process:

```bash
nix-remote-setup <hostname>
```

This copies the age key, SSH key, creates `nix.conf`, clones the repo, and
decrypts the cache key on the remote host.

### Darwin (macOS)

Bootstrap nix-darwin first (one-time only):

```bash
mkdir -p ~/.config/nix-darwin
cd ~/.config/nix-darwin
nix flake init -t nix-darwin
sed -i '' "s/simple/$(scutil --get LocalHostName)/" flake.nix
```

Edit `flake.nix` to enable nh and fix the platform for your system:

```nix
programs.nh.enable = true;
```

Run the initial switch:

```bash
nix run nix-darwin -- switch --flake ~/.config/nix-darwin
```

Log out and back in, then run the real install (will take some time):

```bash
nh darwin switch --impure
```

Clean up the bootstrap:

```bash
rm -rf ~/.config/nix-darwin
```

### NixOS

```bash
sudo nixos-rebuild switch --flake ~/.config/nix/config/ --impure
```

### Proxmox LXC Containers

```bash
# Build Proxmox LXC image
rebuild --proxmox-lxc

# Upload to Proxmox, create container, then deploy
rebuild -vL <machine-name>
```

## Applying Changes

```bash
rebuild
```

The `rebuild` command is a Python-based deployment tool that:

- Automatically decrypts the cache signing key if needed
- Includes `--impure` (required for `private/` submodule access via
  `builtins.fetchGit`)
- Uses `nh` for a better rebuild experience
- Supports local, remote, and parallel deployments

### Common Patterns

```bash
# Rebuild the current machine (most common)
rebuild

# Deploy to a remote machine (prebuild locally, remote activates from cache)
rebuild aether

# Deploy to a remote LXC (build locally, push closure via SSH)
rebuild -vL moltbot

# Deploy to all machines of a type
rebuild @nixos
rebuild @darwin

# Deploy to all machines in parallel
rebuild -p --all

# Dry run (show what would be deployed)
rebuild -n @nixos

# List all nodes and tags
rebuild --list

# Build Proxmox images
rebuild --proxmox        # Both VM (qcow2) and LXC
rebuild --proxmox-lxc    # LXC image only
rebuild --proxmox-vm-qcow2  # VM image only
```

### Deployment Modes

| Flag      | Mode                       | Description                                                 |
| --------- | -------------------------- | ----------------------------------------------------------- |
| (default) | prebuild + remote activate | Builds locally to populate cache, remote fetches from cache |
| `-L`      | local build + push         | Builds locally and pushes closure to remote via SSH         |
| `-R`      | remote build               | SSHes into remote and builds there directly                 |

### Manual Rebuilds

```bash
# With nh (recommended)
nh darwin switch --impure

# With darwin-rebuild
darwin-rebuild switch --flake .#$(hostname -s) --impure

# With nixos-rebuild
sudo nixos-rebuild switch --flake . --impure
```

## Architecture

```
flake.nix                # Entry point — inputs, machine definitions, helper functions
├── darwin.nix           # Darwin system-level config (Homebrew, Dock, linux-builder VM)
├── nixos.nix            # NixOS system-level config (role-based module imports)
├── home.nix             # Home-manager base config (role-based module composition)
│
├── shared/              # Cross-platform utilities
│   ├── helpers.nix      # YAML/TOML conversion, global variables, theme config, git helpers
│   ├── roles.nix        # Role-based module composition (workstation/headless/minimal)
│   ├── shell-common.nix # Shell functions for fish/bash/zsh, standalone scripts
│   ├── build.nix        # Distributed build config
│   ├── cache.nix        # Binary cache (NCPS, cachix, cache.nixos.org) + post-build upload
│   ├── deploy.nix       # Deployment node configuration from private/nodes.json
│   ├── packages.nix     # Custom packages (lazyworktree, worktrunk, ccusage, pve-exporter)
│   ├── overlays.nix     # Lix package overlay
│   ├── themes.nix       # Catppuccin Macchiato theme definitions
│   ├── fonts-common.nix # Font definitions (Nerd Fonts, Noto, Monaspace)
│   ├── fish-plugins.nix # Fish plugin definitions
│   ├── age-home.nix     # Patched agenix HM module (fixes stale generation crash loop)
│   └── shells.nix       # Cross-platform shell enablement
│
├── darwin/              # macOS system modules
│   ├── brew.nix         # Homebrew taps, formulas, casks
│   ├── dock.nix         # Dock layout, apps, hot corners
│   ├── settings.nix     # macOS defaults (keyboard, Finder, trackpad)
│   ├── security.nix     # Security tools (1Password, Wireshark)
│   ├── tiling.nix       # Aerospace window manager
│   └── ...              # 19 more modules (fonts, media, dev, etc.)
│
├── nixos/               # NixOS system modules
│   ├── machines/        # 19 machine-specific configurations
│   ├── hardware/        # 31 hardware configs (LXC boilerplate, device definitions)
│   ├── proxmox/         # Proxmox templates (lxc.nix, vm.nix, persistence.nix, common.nix)
│   ├── display_gnome.nix, display_sway.nix  # Desktop environments
│   ├── audio.nix        # PipeWire audio
│   └── ...              # 10 more modules (security, shells, users, etc.)
│
├── home/
│   ├── common/          # Cross-platform home-manager modules
│   │   ├── ai/          # Claude Code, OpenCode, Codex CLI, Gemini CLI, MCP servers, GSD framework
│   │   ├── core/        # Git (gh, delta, lefthook), Nix, agenix, fonts, SSH
│   │   ├── dev/         # Go, Node.js/Bun, Python, Java, Clojure, C/C++, Android, embedded
│   │   ├── editors/     # Neovim (LazyVim), Emacs (Doom), VS Code
│   │   ├── infra/       # Docker, Kubernetes (kubectl, helm, k9s), AWS/GCP, Terraform
│   │   ├── media/       # FFmpeg, ImageMagick, yt-dlp
│   │   ├── security/    # GPG, security scanning tools
│   │   ├── shell/       # Fish, Bash, Zsh, Starship, Tmux, Ghostty, Kitty
│   │   ├── sync/        # Mutagen file synchronization (hub-and-spoke with aether)
│   │   └── utils/       # aichat, ripgrep-all, httpie, hugo, topgrade, and more
│   ├── macos/           # Aerospace, BetterTouchTool, Sketchybar
│   └── linux/           # Display, systemd, Linux-specific security/shell
│
├── scripts/             # Standalone operational scripts
│   ├── pve-sysctl-setup.sh  # Configure Proxmox host sysctl for LXC services
│   └── lxc-add-machine      # Register new LXC machine to agenix secrets
│
└── private/             # Git submodule — encrypted secrets, sensitive configs
```

## Role System

Machines are assigned one of three roles that control which home-manager modules
are imported:

| Role            | Purpose                  | Includes                                                                     |
| --------------- | ------------------------ | ---------------------------------------------------------------------------- |
| **workstation** | Full GUI experience      | Everything: AI, dev tools, editors, GUI terminals, media, window managers    |
| **headless**    | CLI-only dev environment | AI, dev tools, editors, infra tools, file sync — no GUI apps                 |
| **minimal**     | Familiar shell only      | Fish, Bash, Zsh, Starship, Tmux, essential CLI tools (rg, fd, bat, eza, fzf) |

Roles compose from building blocks defined in `shared/roles.nix`:

```
workstation = base + ai + dev + editors + infra + utils + sync + media + guiShell + [platform-specific]
headless    = base + ai + dev + editors + infra + utils + sync + [linux CLI]
minimal     = coreMinimal + shellMinimal + [linux systemd]
```

Where `base = fullCore + shellAll + security`.

## Available Commands

### Shell Functions

| Command             | Description                                                           |
| ------------------- | --------------------------------------------------------------------- |
| `rebuild`           | Nix deployment tool — see [Applying Changes](#applying-changes)       |
| `c`                 | Open Claude Code in a tmux session (auto-names session from git repo) |
| `co` / `oc`         | Open OpenCode in a tmux session                                       |
| `ca`                | Attach to an existing tmux session via fzf                            |
| `mkcd <dir>`        | Create a directory and cd into it                                     |
| `private` / `p`     | Toggle private mode (disables shell + Atuin history)                  |
| `rga-fzf <pattern>` | Ripgrep-all with fzf preview                                          |
| `flushdns`          | Flush DNS cache (macOS only)                                          |
| `help <cmd>`        | Show command help with bat syntax highlighting                        |

### Shell Aliases

| Alias   | Expands To                                          | Condition       |
| ------- | --------------------------------------------------- | --------------- |
| `cat`   | `bat -p`                                            | bat enabled     |
| `man`   | `batman`                                            | bat enabled     |
| `ls`    | `eza --icons -F -H --group-directories-first --git` | eza enabled     |
| `dig`   | `doggo`                                             | doggo installed |
| `ping`  | `gping`                                             | gping installed |
| `watch` | `viddy`                                             | viddy installed |

### Operational Scripts

| Script                                | Description                                                             |
| ------------------------------------- | ----------------------------------------------------------------------- |
| `nix-remote-setup <host>`             | Prepare a remote machine for this nix config (copies keys, clones repo) |
| `lxc-add-machine <name> <ssh-target>` | Register a new LXC to agenix secrets                                    |
| `pve-sysctl-setup.sh`                 | Configure Proxmox host sysctl for LXC networking                        |

## Proxmox Infrastructure

### Cluster

Three Proxmox nodes (pve1, pve2, pve3) running a total of 21 LXC containers.

### Persistence Model

All LXCs use **ephemeral tmpfs root** with **bind-mounted persistence** from
`/nix/persist`:

1. Container boots with tmpfs root (ephemeral)
2. `create-persist-dirs` service creates persistence directories
3. Systemd bind-mounts `/nix/persist/<path>` to `/<path>` before services start
4. On reboot, ephemeral root is discarded; data in `/nix/persist` survives

**Always persisted** (all LXCs): `/etc/nixos`, `/var/lib/systemd`, `/var/log`,
`/home`, `/etc/machine-id`, SSH host keys.

**Per-machine extras**: Service data (e.g., `/var/lib/mosquitto`), Docker
volumes, ACME certificates.

### Daemon LXC Pattern

The `mkDaemonLXCs` helper generates identical configurations across all 3
Proxmox nodes for high-availability services:

```nix
mkDaemonLXCs {
  name = "cloudflared";
  hardware = node: ./nixos/hardware/cloudflared-${node}.nix;
}
# Produces: cloudflared-pve1, cloudflared-pve2, cloudflared-pve3
```

### Building Proxmox Images

```bash
rebuild --proxmox-lxc        # LXC tarball (.tar.xz)
rebuild --proxmox-vm-qcow2   # VM image (.qcow2) — import with: qm importdisk <vmid> <file> <storage>
```

## Key Patterns

### Module SpecialArgs

Every configuration receives these parameters for per-machine customization:

```nix
{ machine, shared, private, role, platform, pkgs-unstable, inputs, claudebox, ... }
```

### Private Submodule Access

Due to nix flakes not including submodule contents, the flake uses
`builtins.fetchGit` with `submodules = true`. Modules reference private files
using the `private` variable:

```nix
{ config, pkgs, private, ... }:
{
  age.secrets."my-secret" = {
    file = "${private}/path/to/my-secret.age";
    path = "${config.home.homeDirectory}/.secrets/my-secret";
  };
}
```

Rebuilds require `--impure` (the `rebuild` command handles this automatically).

### Binary Cache

All builds are automatically uploaded to the self-hosted NCPS cache
(`ncps.hyades.io`) via a post-build hook. The cache signing key is age-encrypted
in the private submodule and auto-decrypted by `rebuild`.

### Secrets Management

Age-encrypted files live in `private/`. The identity key is at `~/.age/age.pem`.
Secrets are decrypted at activation time and mounted to temp directories
(`DARWIN_USER_TEMP_DIR` on macOS, `XDG_RUNTIME_DIR` on Linux).

### Cross-Platform Shell Functions

Shell functions exist as separate `.fish` and `.sh` files in
`shared/resources/shell/` because Fish has fundamentally incompatible syntax
with Bash/Zsh (different variable assignment, control flow, argument handling).
Simple commands that use no variables or control flow can be shared as-is.

Dynamic values use `@placeholder@` template substitution, applied at Nix
evaluation time.

### Catppuccin Theme

A single theme definition in `shared/helpers.nix` provides pre-computed variant
names for every naming convention used across tools:

```nix
theme.variants = {
  underscore = "catppuccin_macchiato";     # btop, starship
  hyphen = "catppuccin-macchiato";         # ghostty, git
  titleSpace = "Catppuccin Macchiato";     # bat
  variantOnly = "macchiato";               # yazi
};
```

### Git and Nix Flakes

**New files must be committed before Nix can see them.** Nix flakes only
evaluate files tracked by git. Modified existing files work without committing.
The `private/` submodule requires separate commits — commit there first, then
update the submodule reference in the main repo.

### Linux Builder VM (Darwin)

Darwin machines include a Linux builder VM (`nix.linux-builder`) for
cross-platform builds. It runs aarch64-linux natively and emulates x86_64-linux
via binfmt/qemu, enabling `rebuild aether` from macOS.

## Private Submodule

The `private/` directory is a git submodule containing encrypted secrets and
sensitive configurations.

### Adding New Private Resources

1. Add and commit files in the `private/` submodule first
2. In modules, add `private` to the function parameters:
   `{ config, pkgs, private, ... }:`
3. Use `"${private}/relative/path"` to reference the file
4. Commit the submodule reference update in the main repo
5. Rebuild with `--impure` flag

### Adding a New Machine to Secrets

For LXC containers that need access to shared secrets:

```bash
lxc-add-machine <machine-name> <ssh-target>
# Example: lxc-add-machine atuin root@10.23.23.124
```

This fetches the machine's SSH host key, adds it to the secrets recipients, and
re-encrypts.

## Troubleshooting

### Cache Timeout Errors

```
error: unable to download 'https://ncps.hyades.io/...': Connection timed out
```

This is **not benign** — the build was interrupted and packages may not be
installed. Run `rebuild` again until it completes without cache errors.

### LXC Deployments Timing Out

Always use `-vL` flags for LXC deployments to build locally and stream output:

```bash
rebuild -vL cloudflared
```

- `-v` streams output in real-time (prevents SSH timeout on long builds)
- `-L` builds locally and pushes to remote (faster, avoids copying keys to LXC)

### Tailscale Connectivity

The `rebuild` tool detects Tailscale connectivity and automatically skips
`100.x.x.x` addresses if Tailscale is disconnected, falling back to LAN
addresses.

### Stale Generations

The patched agenix module (`shared/age-home.nix`) fixes a crash loop that occurs
when stale home-manager generations reference secrets that can no longer be
decrypted. If you see activation failures, clear old generations:

```bash
home-manager generations | tail -n +2 | awk '{print $NF}' | xargs -I{} home-manager remove-generations {}
```
