# Changelog

This changelog tracks major milestones and notable changes in this personal Nix
flake configuration. Since this is a private infrastructure repository, it uses
date-based sections rather than semantic versioning.

## 2026-04

### Added

- better-ccflare background service with launchd (macOS) and systemd (Linux)
  support.
- RTK (Rust Token Killer) CLI proxy for token-optimized dev operations.
- Web-ui-designer skill with Iniciador design system theme.
- doc-writer and doc-verifier Claude Code agents for documentation generation.

### Changed

- Updated GSD framework from v1.29.0 to v1.34.2.
- Made Mermaid diagrams mandatory in docs and readme skills.
- Set Claude Code default permission mode to auto.
- Deployed skills to ~/.claude/skills/ for Claude Code discovery.
- Made web-ui-designer skill technology-agnostic.
- Merged resolve-conversations and resolve-code-scanning into unified fix-pr
  skill.
- Added .context to global gitignore.

### Fixed

- RTK hash mismatch for v0.35.0 re-release.
- Bash direnv hook moved from sessionVariablesExtra to profileExtra.

### Removed

- TDD Guard tool from nix config.
- secrets-scanner Claude Code plugin.

## 2026-03

### Added

- OpenCode AI IDE integration alongside Claude Code, Codex, and Gemini.
- NanoClaw personal AI agent for WhatsApp and Telegram via Docker.
- GSD (Get Shit Done) framework for structured AI agent task management.
- Mutagen hub-and-spoke file synchronization with dedicated LXC hub.
- Comprehensive project documentation suite and automated README generation.
- Aikido security scanning and Playwriter MCP servers for AI agents.
- nixd language server for Nix LSP support in editors.
- oh-my-opencode v3.13.1 with expanded model and agent configurations.
- `/readme` and `/docs` slash commands for AI agent documentation generation.

### Changed

- Switched to direct NFS mounts for Mutagen and Aether dev environments.
- Boosted CPU and RAM resources during LXC rebuilds for faster deployments.
- Migrated Aether dev environment to a Proxmox LXC container.
- Routed Claude models through ccflare proxy after fixing billing header in
  better-ccflare fork.
- Switched explore and small_model agents from Grok/Haiku to MiniMax M2.5 for
  better quality at zero cost.
- Ported Claude Code agents and commands to OpenCode environment.
- Switched Slack MCP to korotovsky/slack-mcp-server.

### Fixed

- better-ccflare proxy returning 400 for Sonnet/Opus models (missing billing
  header injection for OAuth accounts).
- Tmux session handling for AI agent shell sessions (SIGINT trapping, explicit
  bash for default-shell).

## 2026-02

### Added

- Centralized monitoring stack with Prometheus, Grafana, and InfluxDB v2.
- IPMI sensor monitoring and hardware metrics for Proxmox hosts.
- ccflare Claude API proxy for improved reliability and bypass capabilities.
- Let's Encrypt HTTPS for NCPS cache via Cloudflare DNS-01 challenges.
- TCP tuning and file descriptor limits for high-performance LXC services.

### Changed

- Replaced Python-based PVE exporter with a high-performance Go implementation.
- Migrated Proxmox metrics to native InfluxDB v2 integration.

## 2026-01

### Added

- Moltbot AI assistant gateway migrated to a dedicated Proxmox LXC.
- Minimal system role for reduced disk usage in utility LXC containers.
- Proxmox sysctl setup script for optimized LXC networking.
- Root user configuration for all NixOS hosts.

### Changed

- Increased memory limits for Home Assistant (HAOS) to 10GB.
- Streamlined AI agent orchestration via Agent Teams.

## 2025-12

### Added

- Claude Code integration with custom rules, memory, and TDD tooling.
- NCPS (Nix Cache Proxy) for local binary caching and faster rebuilds.
- Distributed build support across multiple machines via SSH.
- Tmux terminal automation and session management for AI agents.
- Atuin shell history synchronization across all systems.

### Changed

- Consolidated shared helpers and cross-platform modules.
- Migrated from symlinks to ${private} pattern for secret access.
