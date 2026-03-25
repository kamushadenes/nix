# Changelog

This changelog tracks major milestones and notable changes in this personal Nix
flake configuration. Since this is a private infrastructure repository, it uses
date-based sections rather than semantic versioning.

## 2026-03

### Added

- OpenCode AI IDE integration alongside Claude Code, Codex, and Gemini.
- NanoClaw personal AI agent for WhatsApp and Telegram via Docker.
- GSD (Get Stuff Done) framework for structured AI agent task management.
- Mutagen hub-and-spoke file synchronization with dedicated LXC hub.
- Comprehensive project documentation suite and automated README generation.
- Aikido security scanning and Playwriter MCP servers for AI agents.

### Changed

- Switched to direct NFS mounts for Mutagen and Aether dev environments.
- Boosted CPU and RAM resources during LXC rebuilds for faster deployments.
- Migrated Aether dev environment to a Proxmox LXC container.

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
