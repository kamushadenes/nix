# External Integrations

**Analysis Date:** 2026-02-21

## APIs & External Services

**AI Services:**
- Anthropic Claude API - Used by Claude Code (Homebrew on Darwin, pkgs-unstable on Linux) and Moltbot gateway
  - SDK/Client: `claude-code` CLI, `moltbot-gateway`
  - Auth: Anthropic API key (agenix-encrypted in `private/nixos/secrets/moltbot/anthropic-api-key.age`)
- OpenAI - Used by Codex CLI
  - SDK/Client: `codex` CLI (`home/common/ai/codex-cli.nix`)
  - Auth: OAuth (managed by codex CLI)
- Google Gemini API - Used by Gemini CLI and Moltbot gateway
  - SDK/Client: `gemini-cli` (`home/common/ai/gemini-cli.nix`)
  - Auth: `@GOOGLE_API_KEY@` for Moltbot, OAuth for Gemini CLI
- OpenRouter API - Routing to multiple AI models
  - Auth: `@OPENROUTER_API_KEY@` (agenix secret at `private/home/common/ai/resources/claude/openrouter-api-key.age`)

**MCP (Model Context Protocol) Servers:**
- DeepWiki - `https://mcp.deepwiki.com/mcp` (HTTP, public, no auth)
  - Purpose: GitHub repository documentation for AI agents
  - Enabled for: Claude Code, Codex CLI, Gemini CLI
  - Config: `home/common/ai/mcp-servers.nix:39`
- GitHub MCP - `github-mcp-server` (stdio)
  - Purpose: Repository management, issues, PRs, code search
  - Auth: `@GITHUB_PAT@` (agenix secret at `private/home/common/ai/resources/claude/github-pat.age`)
  - Enabled for: Claude Code
  - Config: `home/common/ai/mcp-servers.nix:43`
- Ref - `https://api.ref.tools/mcp` (HTTP)
  - Purpose: Documentation search
  - Auth: `@REF_API_KEY@` header (agenix secret at `private/home/common/ai/resources/claude/ref-api-key.age`)
  - Enabled for: Claude Code, Codex CLI, Gemini CLI
  - Config: `home/common/ai/mcp-servers.nix:55`
- Repomix - `npx repomix --mcp` (stdio)
  - Purpose: Codebase packaging for AI analysis
  - Enabled for: Codex CLI, Gemini CLI
  - Config: `home/common/ai/mcp-servers.nix:63`
- godoc-mcp - `godoc-mcp` binary (stdio)
  - Purpose: Go documentation access
  - Enabled for: Codex CLI, Gemini CLI
  - Config: `home/common/ai/mcp-servers.nix:75`
- Terraform MCP - Docker container `hashicorp/terraform-mcp-server` (stdio)
  - Purpose: Terraform Cloud/Enterprise integration
  - Auth: `@TFE_TOKEN@` (agenix secret at `private/home/common/ai/resources/claude/tfe-token.age`)
  - Enabled for: Codex CLI, Gemini CLI
  - Config: `home/common/ai/mcp-servers.nix:83`
- Orchestrator MCP - `uvx python server.py` (stdio)
  - Purpose: Terminal automation (tmux_* tools), desktop notifications
  - Server script: `home/common/ai/resources/claude-code/scripts/orchestrator-mcp-server.py`
  - Deployed to: `~/.config/orchestrator-mcp/server.py`
  - Enabled for: Claude Code, Codex CLI, Gemini CLI
  - Config: `home/common/ai/mcp-servers.nix:98`
- Private MCP servers loaded from `private/home/common/ai/mcp-servers-private.nix` (workspace-specific: ClickUp, Vanta, etc.)

**Search & Discovery:**
- Brave Search API - Used by Moltbot gateway for web search
  - Auth: `BRAVE_SEARCH_API_KEY` (agenix secret at `private/nixos/secrets/moltbot/brave-api-key.age`)

**Communication:**
- Telegram Bot API - Used by Moltbot gateway as primary chat interface
  - SDK/Client: `moltbot-gateway` binary (`nixos/machines/moltbot.nix`)
  - Auth: `TELEGRAM_BOT_TOKEN` (agenix secret)
- WAHA (WhatsApp HTTP API) - WhatsApp integration
  - Docker container: `devlikeapro/waha-plus:gows` (`nixos/machines/waha.nix`)
  - API endpoint: `https://waha.hyades.io`
  - Port: 3000

**Email:**
- Fastmail - Used by Moltbot for email integration
  - Auth: `FASTMAIL_USER=kamus@hadenes.io`, `FASTMAIL_PASSWORD` (agenix secret)
  - Config: `nixos/machines/moltbot.nix:98-99`

## Data Storage

**Databases:**
- SQLite - Used by Atuin sync server (`nixos/machines/atuin.nix:12`), ncps cache (`nixos/machines/ncps.nix:39`)
- PostgreSQL client tools installed (`home/common/infra/db.nix`)

**File Storage:**
- NFS mount from TrueNAS at `10.23.23.14:/mnt/HDD/Cache/ncps` for ncps binary cache (`nixos/machines/ncps.nix:12`)
- Cloudflare R2 (S3-compatible) for WAHA media storage (`nixos/machines/waha.nix:89-92`)
- Dropbox - Project files synced via Mutagen (`home/common/sync/mutagen.nix:23-26`)
- Local filesystem for all other persistent data (bind-mounted `/nix/persist` paths on LXCs)

**Caching:**
- ncps (Nix Cache Proxy Server) - Self-hosted at `ncps.hyades.io:8501`
  - Docker container `kalbasit/ncps:latest` (`nixos/machines/ncps.nix:29`)
  - Upstream caches: `cache.nixos.org`, `nix-community.cachix.org`
  - Storage: NFS-mounted `/mnt/ncps`
  - Cache signing key: `private/cache-priv-key.pem.age`

## Authentication & Identity

**SSH Key Signing:**
- 1Password app for SSH signing (`home/common/core/git.nix:92-96`)
  - Darwin: `/Applications/1Password.app/Contents/MacOS/op-ssh-sign`
  - Linux: `pkgs._1password-gui` `op-ssh-sign`
- Ed25519 SSH key managed via agenix (`home/common/core/git.nix:91`)

**GPG:**
- 4 GPG private keys managed via agenix (`home/common/security/gpg.nix`)
- Immutable keys/trust (`mutableKeys = false`, `mutableTrust = false`)

**Age Encryption:**
- Identity: `~/.age/age.pem`
- YubiKey plugin: `age-plugin-yubikey` installed (`home/common/security/tools.nix:8`)
- SSH host keys for LXC secret decryption: `/nix/persist/etc/ssh/ssh_host_ed25519_key`

**GitHub:**
- gh CLI with SSH protocol, credential helper (`home/common/core/git.nix:32`)
- GitHub PAT for MCP server access (agenix-encrypted)
- Git signing via 1Password SSH key

**Terraform Cloud:**
- Token: `@TFE_TOKEN@` at `https://app.terraform.io`

## Monitoring & Observability

**Error Tracking:**
- None (no centralized error tracking service)

**Logs:**
- systemd journal for all NixOS services
- WAHA: JSON format logging (`nixos/machines/waha.nix:79`)
- Mutagen daemon: `/tmp/mutagen.{out,err}.log` on Darwin (`home/common/sync/mutagen.nix:133-134`)

**System Monitoring:**
- btop, bottom, glances, htop - Interactive system monitors (`home/common/shell/misc.nix`)
- bandwhich - Network bandwidth by process
- steampipe - Cloud governance queries (`home/common/infra/cloud.nix:11`)
- wakatime-cli - Developer time tracking (`home/common/dev/dev.nix:12`)

## CI/CD & Deployment

**Hosting:**
- Proxmox VE cluster (3 nodes: pve1=10.23.5.10, pve2=10.23.5.11, pve3=10.23.5.12)
  - LXC containers for services (persistent root with bind-mount overrides via `nixos/proxmox/persistence.nix`)
  - Image generation via nixos-generators (`flake.nix:357-379`)

**Deployment Tool:**
- `rebuild` - Custom Python deployment script (`shared/resources/deploy.py` via `shared/shell-common.nix:74`)
  - Parallel execution, tag-based filtering (`@darwin`, `@nixos`, `@workstation`, `@headless`, `@minimal`)
  - Node config from `private/nodes.json` (`shared/deploy.nix`)
  - Local builds with push to remote for LXCs (`-L` flag)
  - Cache key decryption via age before builds

**CI Pipeline:**
- No CI/CD pipeline (no `.github/` directory)
- Pre-commit hooks via lefthook: `nixfmt -v` on `*.nix` files (`lefthook.yml`)
- `act` installed for local GitHub Actions testing (`home/common/dev/dev.nix:8`)

**Remote Setup:**
- `nix-remote-setup` script for bootstrapping new machines (`shared/packages.nix:111`)
  - Copies age key, SSH key, creates nix.conf, clones repo, decrypts cache key
- `lxc-add-machine` script for registering new LXC containers (`scripts/lxc-add-machine`)

## Network Services (Self-Hosted)

**Atuin Sync Server:**
- Shell history synchronization
- Endpoint: `https://atuin.hyades.io` (port 8888 on LXC)
- SQLite backend, registration closed
- Config: `nixos/machines/atuin.nix`

**Mosquitto MQTT Broker:**
- Home Assistant IoT messaging
- Port: 1883, password-authenticated
- Config: `nixos/machines/mqtt.nix`

**Zigbee2MQTT:**
- Zigbee device coordinator for Home Assistant
- Config: `nixos/machines/zigbee2mqtt.nix`

**ESPHome:**
- ESP device builder/interface for Home Assistant
- Docker-based on LXC
- Config: `nixos/machines/esphome.nix`

**Home Assistant:**
- Native NixOS service (not Docker), unstable channel
- Custom components and Lovelace modules (`nixos/machines/haos-custom-components.nix`, `nixos/machines/haos-lovelace-modules.nix`)
- Integrations: ESPHome, MQTT, HomeKit, Zigbee, Unifi, Spotify, etc.
- Config: `nixos/machines/haos.nix`

**Moltbot Gateway:**
- AI assistant gateway for Telegram
- Port: 18789 (HTTP API)
- Skills: CalDAV calendar
- Dependencies: vdirsyncer, khal
- Config: `nixos/machines/moltbot.nix`

**Cloudflare Tunnels:**
- Token-based HA tunnels on all 3 Proxmox nodes (`cloudflared-pve1`, `cloudflared-pve2`, `cloudflared-pve3`)
- Dashboard-managed, all nodes share same tunnel token
- Config: `nixos/machines/cloudflared.nix`

**Tailscale Subnet Router:**
- VPN/mesh networking on all 3 Proxmox nodes (`tailscale-pve1`, `tailscale-pve2`, `tailscale-pve3`)
- Each node has unique state (machine identity)
- Both subnet router and exit node capability
- Config: `nixos/machines/tailscale.nix`

## Webhooks & Callbacks

**Incoming:**
- Moltbot HTTP API on port 18789 (Telegram bot webhook)
- WAHA HTTP API on port 3000 (WhatsApp webhook/polling)

**Outgoing:**
- Moltbot -> Telegram Bot API (message sending)
- WAHA -> WhatsApp API (message sending)
- Cloudflared -> Cloudflare Tunnel API (tunnel registration)
- Tailscale -> Tailscale coordination server

## Environment Configuration

**Required env vars (development machines):**
- `NH_FLAKE` - Points to nix config with submodules
- `EDITOR=nvim`
- `ENABLE_TOOL_SEARCH=true`, `ENABLE_LSP_TOOLS=1` - Claude Code features
- `HOMEBREW_SSH_CONFIG_PATH` - Homebrew SSH workaround (Darwin)
- All defined in `shared/helpers.nix` globalVariables.base

**Required secrets (agenix-encrypted in `private/`):**
- `~/.age/age.pem` - Age identity key
- SSH keys (ed25519) - Git signing, remote access
- GPG private keys (4 keys)
- AI API keys: GitHub PAT, Ref API key, TFE token, OpenRouter API key
- Service secrets: Telegram bot token, Anthropic/Google/Brave API keys, Fastmail password
- Per-LXC secrets: cloudflared token, mosquitto password, WAHA env, Home Assistant secrets

**Secrets location:**
- Encrypted: `private/` git submodule (age-encrypted `.age` files)
- Decrypted at runtime: `DARWIN_USER_TEMP_DIR/agenix/` (macOS) or `XDG_RUNTIME_DIR/agenix/` (Linux)
- LXC persistent: `/nix/persist/etc/ssh/ssh_host_ed25519_key`

## File Synchronization

**Mutagen (hub-and-spoke):**
- Hub: `aether` (`/home/kamushadenes/Dropbox/Projects`)
- Spokes: All Darwin machines (`/Users/kamushadenes/Dropbox/Projects`)
- Projects synced: Iniciador, Hadenes, Personal, Hyades
- Mode: `two-way-safe` with VCS tracking enabled
- Ignore patterns: node_modules, __pycache__, .terraform, vendor, dist, build, etc.
- Daemon: systemd user service (Linux), launchd agent (Darwin)
- Config: `home/common/sync/mutagen.nix`

---

*Integration audit: 2026-02-21*
