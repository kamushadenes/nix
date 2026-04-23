# Service Reference

This document provides a comprehensive reference for all services and machines
managed by this Nix flake configuration. It covers Proxmox LXC containers,
dedicated NixOS machines, and high-availability daemon services.

## Proxmox Cluster Topology

The infrastructure is hosted on a three-node Proxmox VE cluster. Each node runs
a subset of the services, with some services replicated across all nodes for
high availability.

- **pve1**: 10.23.5.10
- **pve2**: 10.23.5.11
- **pve3**: 10.23.5.12

All LXC containers use an ephemeral tmpfs root with bind-mounted persistence
from `/nix/persist` to ensure data survives reboots while keeping the system
state clean. See
[Architecture > Proxmox Architecture](./architecture.md#proxmox-architecture)
for the full persistence model.

## Table of Contents

- [Summary Table](#summary-table)
- [Singleton Services](#singleton-services)
  - [Atuin](#atuin)
  - [Mosquitto](#mosquitto)
  - [Zigbee2MQTT](#zigbee2mqtt)
  - [ESPHome](#esphome)
  - [NCPS](#ncps)
  - [WAHA](#waha)
  - [Home Assistant](#home-assistant)
  - [Moltbot](#moltbot)
  - [GoClaw](#goclaw)
  - [Prometheus](#prometheus)
  - [Grafana](#grafana)
  - [InfluxDB](#influxdb)
  - [Mutagen](#mutagen)
- [Daemon Services (HA)](#daemon-services-ha)
  - [Cloudflared](#cloudflared)
  - [Tailscale](#tailscale)
  - [Prometheus Exporters](#prometheus-exporters)
- [NixOS Machines](#nixos-machines)
  - [Aether](#aether)
  - [NixOS Workstation](#nixos-workstation)

## Summary Table

| Service        | Machine              | Port(s)    | Docker | Role        | Deploy                      |
| -------------- | -------------------- | ---------- | ------ | ----------- | --------------------------- |
| Atuin          | `atuin`              | 8888       | No     | minimal     | `rebuild -vL atuin`         |
| Mosquitto      | `mqtt`               | 1883       | No     | minimal     | `rebuild -vL mqtt`          |
| Zigbee2MQTT    | `zigbee2mqtt`        | 8080       | No     | minimal     | `rebuild -vL zigbee2mqtt`   |
| ESPHome        | `esphome`            | 6052       | Yes    | minimal     | `rebuild -vL esphome`       |
| NCPS           | `ncps`               | 443, 8501  | Yes    | minimal     | `rebuild -vL ncps`          |
| WAHA           | `waha`               | 3000       | Yes    | minimal     | `rebuild -vL waha`          |
| Home Assistant | `haos`               | 8123       | No     | minimal     | `rebuild -vL haos`          |
| Moltbot        | `moltbot`            | 18789      | No     | minimal     | `rebuild -vL moltbot`       |
| GoClaw         | `goclaw`             | 18790      | Yes    | headless    | `rebuild -vL goclaw`        |
| Prometheus     | `prometheus`         | 9090, 9100, 9222 | No     | minimal     | `rebuild -vL prometheus`    |
| Grafana        | `grafana`            | 3000       | No     | minimal     | `rebuild -vL grafana`       |
| InfluxDB       | `influxdb`           | 8086       | No     | minimal     | `rebuild -vL influxdb`      |
| Mutagen        | `mutagen`            | -          | No     | minimal     | `rebuild -vL mutagen`       |
| Cloudflared    | `cloudflared-pve*`   | 33399      | No     | minimal     | `rebuild -vL cloudflared`   |
| Tailscale      | `tailscale-pve*`     | 41641      | No     | minimal     | `rebuild -vL tailscale`     |
| Prom Exporters | `prom-exporter-pve*` | 9100, 9290 | No     | minimal     | `rebuild -vL prom-exporter` |
| Aether         | `aether`             | 3000       | Yes    | headless    | `rebuild aether`            |
| NixOS          | `nixos`              | -          | Yes    | workstation | `rebuild`                   |

## Singleton Services

### Atuin

Shell history sync server using a SQLite backend.

- **What it runs**: Atuin sync server
- **Port(s)**: 8888 (HTTP)
- **Secrets**: None (uses local SQLite database)
- **Persistence**: `/var/lib/atuin`
- **Docker**: No
- **User**: `atuin` (static system user)
- **Dependencies**: None
- **Deploy command**: `rebuild -vL atuin`
- **Health check**: `curl http://localhost:8888/v1/status`
- **Key configuration**: Uses a local SQLite database at
  `/var/lib/atuin/atuin.db` instead of PostgreSQL. Registration is closed by
  default.

### Mosquitto

MQTT broker serving as the central communication hub for Home Assistant and
Zigbee2MQTT.

- **What it runs**: Mosquitto MQTT Broker
- **Port(s)**: 1883 (MQTT)
- **Secrets**: `mosquitto-passwd` (agenix)
- **Persistence**: `/var/lib/mosquitto`
- **Docker**: No
- **User**: `mosquitto` (static system user)
- **Dependencies**: None
- **Deploy command**: `rebuild -vL mqtt`
- **Health check**: `mosquitto_sub -h localhost -t '$SYS/#' -C 1`
- **Key configuration**: Anonymous access is disabled. Authentication is handled
  via a password file generated from agenix secrets.

### Zigbee2MQTT

Bridge between Zigbee devices and the MQTT broker.

- **What it runs**: Zigbee2MQTT
- **Port(s)**: 8080 (Web Frontend)
- **Secrets**: `zigbee2mqtt-mqtt-password` (agenix)
- **Persistence**: `/var/lib/zigbee2mqtt`
- **Docker**: No
- **User**: `zigbee2mqtt` (static system user)
- **Dependencies**: `mqtt` service (external)
- **Deploy command**: `rebuild -vL zigbee2mqtt`
- **Health check**: Access the web UI at port 8080 or check logs for successful
  MQTT connection.
- **Key configuration**: Uses a Sonoff Zigbee 3.0 USB Dongle Plus V2 with the
  `ember` adapter on channel 25. Frontend is enabled for device management.

### ESPHome

Dashboard and build environment for ESP8266/ESP32 firmware.

- **What it runs**: ESPHome Dashboard (Docker)
- **Port(s)**: 6052 (Web UI)
- **Secrets**: `esphome-secrets.yaml` (agenix)
- **Persistence**: `/var/lib/esphome`, `/var/lib/docker`
- **Docker**: Yes (`ghcr.io/esphome/esphome:latest`)
- **User**: `root` (inside container)
- **Dependencies**: None
- **Deploy command**: `rebuild -vL esphome`
- **Health check**: Access the dashboard at port 6052.
- **Key configuration**: Runs in privileged mode with host networking to allow
  mDNS discovery and USB device access for flashing.

### NCPS

Nix Cache Proxy Server providing a local binary cache for all machines.

- **What it runs**: NCPS (Docker) + Nginx
- **Port(s)**: 443 (HTTPS), 8501 (Internal)
- **Secrets**: `cloudflare-dns-token` (agenix)
- **Persistence**: `/var/lib/docker`, `/var/lib/acme`
- **Docker**: Yes (`kalbasit/ncps:latest`)
- **User**: `root` (Docker), `nginx` (Proxy)
- **Dependencies**: NFS mount from TrueNAS for cache storage.
- **Deploy command**: `rebuild -vL ncps`
- **Health check**: `curl https://ncps.hyades.io/nix-cache-info`
- **Key configuration**: Uses ACME with Cloudflare DNS-01 challenges for SSL.
  Proxies to an upstream cache (cache.nixos.org) and signs local builds.

### WAHA

WhatsApp HTTP API gateway for programmatic access to WhatsApp.

- **What it runs**: WAHA Plus (Docker)
- **Port(s)**: 3000 (API)
- **Secrets**: `waha-env`, `docker-token` (agenix)
- **Persistence**: `/var/lib/waha`, `/var/lib/docker`
- **Docker**: Yes (`devlikeapro/waha-plus:gows`)
- **User**: `root` (Docker)
- **Dependencies**: None
- **Deploy command**: `rebuild -vL waha`
- **Health check**: `curl http://localhost:3000/health`
- **Key configuration**: Uses the GOWS engine. Media is stored in a Cloudflare
  R2 bucket via S3-compatible API. Requires a Docker Hub token to pull the
  private image.

### Home Assistant

Central home automation platform running as a native NixOS service.

- **What it runs**: Home Assistant Core
- **Port(s)**: 8123 (Web UI)
- **Secrets**: `haos-secrets.yaml` (agenix)
- **Persistence**: `/var/lib/hass`
- **Docker**: No
- **User**: `hass` (static system user)
- **Dependencies**: `mqtt`, `zigbee2mqtt`, `esphome`
- **Deploy command**: `rebuild -vL haos`
- **Health check**: Access the UI at port 8123.
- **Key configuration**: Uses the unstable package set for latest features.
  Includes a large set of custom components and Lovelace modules. Configuration
  is managed via YAML files in the private submodule.

### Moltbot

Telegram AI assistant gateway providing LLM capabilities to messaging apps.

- **What it runs**: Moltbot Gateway
- **Port(s)**: 18789 (API)
- **Secrets**: `moltbot-telegram-token`, `moltbot-anthropic-key`,
  `moltbot-gateway-token`, `moltbot-google-key`, `moltbot-brave-key`,
  `moltbot-fastmail-password`
- **Persistence**: `/var/lib/moltbot`
- **Docker**: No
- **User**: `moltbot` (static system user)
- **Dependencies**: None
- **Deploy command**: `rebuild -vL moltbot`
- **Health check**: Check if the bot is responsive on Telegram or check
  port 18789.
- **Key configuration**: Includes a CalDAV calendar skill. Workspace and
  configuration are stored in `/var/lib/moltbot`.

### GoClaw

Multi-tenant AI agent platform — Go gateway plus Postgres (pgvector) via Docker
Compose.

- **What it runs**: GoClaw (`ghcr.io/nextlevelbuilder/goclaw:latest`) +
  `pgvector/pgvector:pg18`
- **Port(s)**: 18790 (web dashboard + API)
- **Secrets**: none in agenix; `.env` auto-generated on first boot via upstream
  `prepare-env.sh` plus a random `POSTGRES_PASSWORD`. LLM provider keys are
  configured through the web dashboard.
- **Persistence**: `/var/lib/goclaw`, `/var/lib/docker`
- **Docker**: Yes (compose stack for goclaw + postgres)
- **User**: `goclaw` (normal user in the `docker` group)
- **Dependencies**: None
- **Deploy command**: `rebuild -vL goclaw`
- **Health check**: `systemctl status goclaw` /
  `curl http://10.23.23.9:18790/health`
- **Key configuration**: Clones `nextlevelbuilder/goclaw` to
  `/var/lib/goclaw/app` on first boot, seeds `.env`, then systemd runs
  `docker compose up -d --pull always` for the goclaw + postgres stack.

### Prometheus

Central metrics collection and alerting server.

- **What it runs**: Prometheus + PVE Exporter (Go)
- **Port(s)**: 9090 (UI), 9222 (PVE Exporter), 9100 (node_exporter)
- **Secrets**: `pve-config` (agenix)
- **Persistence**: `/var/lib/prometheus2`
- **Docker**: No
- **User**: `prometheus`
- **Dependencies**: `prom-exporter-pve*`, `cloudflared-pve*`
- **Deploy command**: `rebuild -vL prometheus`
- **Health check**: Access the UI at port 9090.
- **Key configuration**: Scrapes metrics from all containers and Proxmox hosts.
  The custom PVE exporter provides ZFS and SMART data via the Proxmox API.

### Grafana

Visualization platform for monitoring data.

- **What it runs**: Grafana
- **Port(s)**: 3000 (Web UI)
- **Secrets**: `grafana-admin-password`, `grafana-influxdb-token` (agenix)
- **Persistence**: `/var/lib/grafana`
- **Docker**: No
- **User**: `grafana`
- **Dependencies**: `prometheus`, `influxdb`
- **Deploy command**: `rebuild -vL grafana`
- **Health check**: Access the UI at port 3000.
- **Key configuration**: Provisioned with Prometheus and InfluxDB (Flux)
  datasources. Dashboards are deployed as JSON files from the repository.

### InfluxDB

Time-series database for Proxmox native metrics.

- **What it runs**: InfluxDB v2
- **Port(s)**: 8086 (API/UI)
- **Secrets**: `influxdb-admin-password`, `influxdb-admin-token` (agenix)
- **Persistence**: `/var/lib/influxdb2`
- **Docker**: No
- **User**: `influxdb2`
- **Dependencies**: None
- **Deploy command**: `rebuild -vL influxdb`
- **Health check**: Access the UI at port 8086.
- **Key configuration**: Configured to receive metrics directly from Proxmox
  hosts. Uses a 30-day retention policy for the `proxmox` bucket.

### Mutagen

NFS mount hub for file synchronization across the infrastructure.

- **What it runs**: Mutagen Sync Hub
- **Port(s)**: None (Uses SSH)
- **Secrets**: None
- **Persistence**: None (NFS mount only)
- **Docker**: No
- **User**: `kamushadenes`
- **Dependencies**: NFS server (TrueNAS)
- **Deploy command**: `rebuild -vL mutagen`
- **Health check**: `ls /home/kamushadenes/Dropbox`
- **Key configuration**: Privileged container required for NFS mounting.
  Includes a `/Users` symlink for compatibility with macOS paths.

## Daemon Services (HA)

### Cloudflared

Cloudflare Tunnel connectors providing secure external access.

- **What it runs**: Cloudflare Tunnel Daemon
- **Port(s)**: 33399 (Metrics)
- **Secrets**: `cloudflared-token` (agenix)
- **Persistence**: None (Stateless)
- **Docker**: No
- **User**: `cloudflared`
- **Dependencies**: None
- **Deploy command**: `rebuild -vL cloudflared`
- **Health check**: `curl http://localhost:33399/metrics`
- **Key configuration**: Replicated across all Proxmox nodes. All instances
  share the same tunnel token to act as redundant connectors for the same
  tunnel.

### Tailscale

VPN subnet router and exit node for secure network access.

- **What it runs**: Tailscale
- **Port(s)**: 41641 (UDP)
- **Secrets**: None (Managed via Tailscale CLI)
- **Persistence**: `/var/lib/tailscale`
- **Docker**: No
- **User**: `root`
- **Dependencies**: None
- **Deploy command**: `rebuild -vL tailscale`
- **Health check**: `tailscale status`
- **Key configuration**: Advertises routes for internal subnets (10.23.23.0/24,
  10.23.5.0/24, 10.23.2.0/24) and acts as an exit node. Includes a custom route
  fix for local subnet traffic.

### Prometheus Exporters

Hardware and system monitoring agents for Proxmox hosts.

- **What it runs**: node_exporter + IPMI exporter
- **Port(s)**: 9100 (Node), 9290 (IPMI)
- **Secrets**: None
- **Persistence**: None
- **Docker**: No
- **User**: `root`
- **Dependencies**: `/dev/ipmi0` device passthrough from the Proxmox host.
- **Deploy command**: `rebuild -vL prom-exporter`
- **Health check**: `curl http://localhost:9100/metrics` and
  `curl http://localhost:9290/metrics`
- **Key configuration**: Runs on every Proxmox node to provide low-level
  hardware metrics (temperatures, fan speeds) via IPMI.

## NixOS Machines

### Aether

Headless development environment and Docker host.

- **What it runs**: OpenChamber (Docker), Docker host, NFS Dropbox mount
- **Port(s)**: 3000 (Internal OpenChamber UI)
- **Secrets**: `id_ed25519.age`, `id_ed25519.pub.age` (agenix)
- **Persistence**: `/var/lib/docker`, `/var/lib/openchamber`,
  `/home/kamushadenes/.config/openchamber`
- **Docker**: Yes (`openchamber:v1.8.7`)
- **User**: `kamushadenes`
- **Dependencies**: NFS server (TrueNAS)
- **Deploy command**: `rebuild aether`
- **Health check**: Check port 3000 or `docker ps`.
- **Key configuration**: Serves as the central hub for Mutagen sync. OpenChamber
  provides a web-based interface for the OpenCode AI agent.

### NixOS Workstation

Full desktop NixOS installation.

- **What it runs**: GNOME/Sway desktop, development tools, Docker
- **Port(s)**: None (Workstation)
- **Secrets**: None (Uses user-level agenix)
- **Persistence**: None (Standard local installation)
- **Docker**: Yes
- **User**: `kamushadenes`
- **Dependencies**: None
- **Deploy command**: `rebuild`
- **Health check**: System boot and desktop environment availability.
- **Key configuration**: Configured with the `workstation` role, including full
  GUI tools, AI agents, and development environments.
