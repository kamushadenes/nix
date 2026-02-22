# Technology Stack

**Analysis Date:** 2026-02-21

## Languages

**Primary:**
- Nix - All system/home-manager configuration (`flake.nix`, `darwin.nix`, `nixos.nix`, `home.nix`, every `*.nix` file)
- Fish - Primary interactive shell (`home/common/shell/fish.nix`, `shared/resources/shell/*.fish`)
- Bash - Shell scripts for hooks, deployment, CLI tools (`shared/resources/shell/*.sh`, `shared/resources/deploy.py`)
- Python - Claude Code hooks, deployment tool, orchestrator MCP server (`home/common/ai/resources/claude-code/scripts/`)

**Secondary:**
- Lua - Neovim configuration via LazyVim (`home/common/editors/resources/lazyvim/`)
- Go - Custom packages built from source (`shared/packages.nix`: `lazyworktree`, `worktrunk`)
- Emacs Lisp - Doom Emacs config (`home/common/editors/resources/doom/`)

## Runtime

**Nix Implementation:**
- Lix (alternative Nix implementation) from stable package sets
- Package: `pkgs.lixPackageSets.stable.lix` (`darwin.nix:103`, `nixos.nix:89`)
- Overlay at `shared/overlays.nix` replaces `nixpkgs-review`, `nix-eval-jobs`, `nix-fast-build`, `colmena` with Lix equivalents

**Package Channels:**
- Primary: `nixpkgs-25.11-darwin` (stable channel, used for most packages)
- Secondary: `nixpkgs-unstable` (used for frequently-updated tools: `claude-code`, `codex`, `gemini-cli`, `neovim`, `gopls`, `golangci-lint`, `nh`, `devbox`, `biome`, `act`, `supabase-cli`, `dive`, `fabric-ai`, etc.)
- Legacy: `nixpkgs-25.05-darwin` (pinned for agenix compatibility only)

**Lockfile:** `flake.lock` present (managed by `nix flake update`)

## Frameworks

**Core:**
- nix-darwin (25.11 branch) - macOS system configuration (`flake.nix:10`)
- NixOS (25.11 via nixpkgs) - Linux system configuration (`flake.nix:5`)
- home-manager (release-25.11) - User-level configuration (`flake.nix:14`)

**Secrets Management:**
- agenix (ragenix fork) - Age-encrypted secrets with `@PLACEHOLDER@` substitution (`flake.nix:19`)
- Identity: `~/.age/age.pem`

**Image Generation:**
- nixos-generators - Proxmox VM/LXC image building (`flake.nix:37`)

**External Flake Inputs:**
- claudebox (fork) - Sandboxed Claude Code execution (`flake.nix:25`)
- nix-moltbot - Moltbot gateway package and home-manager module (`flake.nix:31`)

## Key Dependencies

**AI Tools (workstation/headless roles):**
- Claude Code - AI coding assistant (Homebrew on Darwin `darwin/brew.nix:18`, `pkgs-unstable` on Linux `home/common/ai/claude-code.nix:163`)
- Codex CLI - OpenAI agent (`home/common/ai/codex-cli.nix`)
- Gemini CLI - Google AI agent (`home/common/ai/gemini-cli.nix`)
- aichat - Multi-model CLI chat (`home/common/utils/aichat.nix`)
- fabric-ai - AI prompt framework (`home/common/utils/utils.nix`)
- GSD framework - Claude Code task orchestration (`home/common/ai/gsd.nix`)
- ccusage - Claude Code usage analytics (`shared/packages.nix:76`)

**MCP Servers (shared across AI tools via `home/common/ai/mcp-servers.nix`):**
- DeepWiki (HTTP) - GitHub repo documentation
- GitHub MCP (stdio) - Repository management via `github-mcp-server`
- Ref (HTTP) - Documentation search
- Repomix (stdio) - Codebase packaging
- godoc-mcp (stdio) - Go documentation
- Terraform MCP (Docker) - Terraform Cloud integration
- Orchestrator MCP (stdio/uvx) - Terminal automation via tmux

**Development Languages:**
- Go - `programs.go.enable = true` with gopls, golangci-lint, govulncheck, gotestsum, cobra-cli, wails, zig (cross-compilation) (`home/common/dev/go.nix`)
- Node.js - bun, nodejs, typescript, yarn-berry (`home/common/dev/node.nix`)
- Python 3.12 - black, pytest, ruff, pyright (`home/common/dev/python.nix`, `home/common/ai/claude-code.nix`)
- Java - `programs.java.enable = true` (`home/common/dev/java.nix`)
- Clojure - babashka, leiningen, clj-kondo, cljfmt (`home/common/dev/clojure.nix`)
- C/C++ - autoconf, automake, cmake, gnumake (`home/common/dev/clang.nix`)
- Rust - rustup (via emacs.nix tools) (`home/common/editors/emacs.nix:67`)
- PHP 8.3 - with composer (via emacs.nix tools) (`home/common/editors/emacs.nix:52`)

**TDD Enforcement:**
- tdd-guard - Core TDD enforcement tool for Claude Code (`home/common/dev/node.nix:4`)
- tdd-guard-go - Go test reporter (`home/common/dev/go.nix:30`)
- tdd-guard-pytest - Python pytest plugin (`home/common/dev/python.nix:6`)
- tdd-guard-vitest - Vitest reporter for TypeScript (`home/common/dev/node.nix:35`)

**Dev Tools:**
- act - GitHub Actions local runner (`home/common/dev/dev.nix:8`)
- just - Task runner (`home/common/dev/dev.nix:14`)
- biome - JS/TS linter/formatter (`home/common/dev/dev.nix:15`)
- supabase-cli - Supabase local dev (`home/common/dev/dev.nix:15`)
- protobuf - Protocol buffers (`home/common/dev/dev.nix:11`)
- aider-chat - AI pair programming (`home/common/dev/dev.nix:14`)
- wakatime-cli - Time tracking (`home/common/dev/dev.nix:12`)
- lazygit - Git TUI (`home/common/dev/lazygit.nix`)
- lazyworktree - Git worktree TUI (`shared/packages.nix:15`, `home/common/dev/lazyworktree.nix`)
- worktrunk - Git worktree management CLI (`shared/packages.nix:46`, `home/common/dev/worktrunk.nix`)
- lefthook - Git hooks manager (`home/common/core/git.nix:12`)

**Editors:**
- Neovim (unstable) - Primary editor with LazyVim config, tree-sitter, Lua 5.1 (`home/common/editors/nvim.nix`)
- Neovide - Neovim GUI (`home/common/editors/nvim.nix:17`)
- Doom Emacs - Secondary editor (currently disabled) (`home/common/editors/emacs.nix:11`)

**Shell Ecosystem:**
- Fish - Primary shell with evalcache, autopair, async-prompt, puffer-fish, safe-rm, spark, ssh-agent plugins (`shared/fish-plugins.nix`)
- Bash/Zsh - Secondary shells for compatibility (`home/common/shell/bash.nix`, `home/common/shell/zsh.nix`)
- Starship - Cross-shell prompt (`home/common/shell/starship.nix`)
- tmux - Terminal multiplexer with catppuccin theme, resurrect, continuum (`home/common/shell/tmux.nix`)
- Ghostty - Terminal emulator on Linux (`home/common/shell/ghostty.nix`)
- Kitty - Terminal emulator (`home/common/shell/kitty.nix`)

**Modern CLI Tools (workstation/headless via `home/common/shell/misc.nix`):**
- ripgrep, fd, fzf, bat (with extras), eza, zoxide - Core replacements
- atuin - Shell history sync (self-hosted server at `atuin.hyades.io`)
- broot, yazi - File managers
- dust, duf - Disk usage
- procs, sd, doggo, xh - Modern ps/sed/dig/curl
- difftastic - AST-aware diffs
- hyperfine - Benchmarking
- tokei - Code stats
- btop, bottom, glances - System monitors
- direnv + nix-direnv - Per-project environments
- navi - Cheatsheet tool
- pay-respects - Command correction

**Minimal CLI Tools (service containers via `home/common/shell/misc-minimal.nix`):**
- ripgrep, fd, bat, eza, fzf, htop, jq, less, nh

**Infrastructure:**
- Docker (client, buildx, compose, credential-helpers, skopeo, lazydocker, dive) (`home/common/infra/docker.nix`)
- Kubernetes (kubectl, kubectx, helm, argocd, kubebuilder, kubeseal, kubeshark, k9s, kind, krew) (`home/common/infra/kubernetes.nix`)
- Terraform + infracost + packer (`home/common/infra/iac.nix`)
- AWS CLI (`home/common/infra/cloud.nix`)
- Google Cloud SDK with GKE auth plugin (`home/common/infra/cloud.nix`)
- Steampipe - Cloud governance (`home/common/infra/cloud.nix`)
- Database clients: sqlite, mycli, pgcli, postgresql (`home/common/infra/db.nix`)

**Security:**
- 1Password CLI - SSH signing, secrets access (`home/common/security/tools.nix`)
- GPG with gpgme (`home/common/security/gpg.nix`)
- age + age-plugin-yubikey - Encryption (`home/common/security/tools.nix`)
- nmap, nuclei, rustscan - Network scanning (`home/common/security/tools.nix`)
- tfsec - Terraform security scanning (`home/common/security/tools.nix`)
- fleetctl - Fleet/osquery management (`home/common/security/tools.nix`)

**File Sync:**
- Mutagen (unstable) - Bidirectional file sync with hub-and-spoke topology (`home/common/sync/mutagen.nix`)
- Hub: aether, Spokes: all Darwin/other NixOS machines
- Syncs project directories via `mutagen-setup` fish function

## Configuration

**Environment:**
- Variables defined in `shared/helpers.nix` (`globalVariables.base`)
- Key vars: `EDITOR=nvim`, `NH_FLAKE`, `DOOMDIR`, `OP_BIN_PATH`, `ENABLE_TOOL_SEARCH=true`, `ENABLE_LSP_TOOLS=1`
- Platform-specific export via `launchctl` (Darwin) or `shell` export (Linux)
- Secrets use `@PLACEHOLDER@` syntax, substituted at activation time via agenix

**Build:**
- `flake.nix` - Entry point, defines all machine configurations
- `flake.lock` - Pinned input versions
- `lefthook.yml` - Pre-commit hook running `nixfmt -v` on `*.nix` files
- `--impure` flag required for builds (private submodule uses `builtins.fetchGit`)

**Binary Cache:**
- Self-hosted: `ncps.hyades.io:8501` (Nix Cache Proxy Server on Proxmox LXC `nixos/machines/ncps.nix`)
- Upstream: `cache.nixos.org`, `nix-community.cachix.org`
- Configuration: `shared/cache.nix` with 5s connect timeout and fallback enabled

**Distributed Builds:**
- ssh-ng protocol (`shared/build.nix`)
- Darwin linux-builder VM: 4 cores, 8GB RAM, 40GB disk, emulates x86_64 via binfmt (`darwin.nix:68`)
- Remote build machines currently disabled (local builds only)

## Platform Requirements

**Development (macOS - aarch64-darwin):**
- Machines: studio, macbook-m3-pro, w-henrique
- Homebrew managed but currently disabled (`darwin/brew.nix:5`)
- Uses nix-darwin + home-manager
- Lix as Nix implementation

**Server (NixOS - x86_64-linux):**
- Workstation: nixos (desktop with GUI)
- Headless: aether (server, Mutagen hub)
- Proxmox LXCs (minimal role): atuin, mqtt, zigbee2mqtt, esphome, ncps, waha, haos, moltbot, cloudflared-{pve1,pve2,pve3}, tailscale-{pve1,pve2,pve3}

**Deployment:**
- `rebuild` command - Python deployment script with parallel execution and tag-based filtering (`shared/resources/deploy.py` via `shared/shell-common.nix`)
- Node configuration from `private/nodes.json` (`shared/deploy.nix`)
- Proxmox images: qcow2 for VMs, proxmox-lxc format for containers (`flake.nix:357`)

## Theme

**Global:** Catppuccin Macchiato applied consistently across:
- Neovim, tmux, ghostty, kitty, starship, btop, bat, fzf, k9s, yazi, git-delta

---

*Stack analysis: 2026-02-21*
