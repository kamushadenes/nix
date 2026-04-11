---
name: migrate-lxc
description: Migrate a non-NixOS LXC container to NixOS with impermanence, handling configuration extraction, secrets via agenix, data migration, and cross-host IP reference resolution. Provide origin SSH, target SSH (or "new"), service type, and description.
---

# Migrate LXC Container to NixOS

Migrate a non-NixOS LXC container to NixOS with impermanence.

## Usage

Provide the following in your instructions:
- `origin_ssh` -- SSH target for the source container (e.g., `root@old-host.local`)
- `new_ssh` -- SSH target for the destination (e.g., `root@new-host.hyades.io`) or `"new"` to create a fresh LXC
- `service_type` -- Service being migrated (e.g., `postgresql`, `nginx`, `docker`)
- `description` -- Human-readable description

When `new_ssh` is `"new"`, a new LXC container is created via the `new-lxc` skill before migration.

## Constants

| Item | Value |
|-|-|
| Proxmox Nodes | pve1: 10.23.5.10, pve2: 10.23.5.11, pve3: 10.23.5.12 |

## PHASE 1: Parse and Validate

### 1.1 Derive machine name

Extract hostname from `new_ssh` (e.g., `root@web-01.hyades.io` -> `web-01`). If the target is an IP, ask the user for a machine name.

### 1.2 Validate connectivity

Test SSH to both hosts. If `new_ssh` is `"new"`, skip new host validation.

```bash
ssh -o ConnectTimeout=5 -o BatchMode=yes <origin_ssh> "hostname && uname -a"
ssh -o ConnectTimeout=5 -o BatchMode=yes <new_ssh> "hostname && nixos-version"
```

### 1.3 Tag existing LXC (when target exists)

If `new_ssh` is NOT `"new"`, find the container across Proxmox nodes and add the `nixos` tag.

### 1.4 Create new LXC (when target is "new")

If `new_ssh` is `"new"`:

1. Find origin container across Proxmox nodes
2. Fetch specs (RAM, cores, disk, VLAN, privileged mode)
3. Apply minimums: RAM max(512, origin), cores max(1, origin), disk max(16, origin)
4. Use the `new-lxc` skill in migration mode with the calculated specs
5. Get the new IP from the output

## PHASE 2: Service Discovery

### 2.1 Detect service configuration

Based on `service_type`, identify config and data paths:

| Service | Config Paths | Data Paths |
|-|-|-|
| postgresql | `/etc/postgresql/*/main/` | `/var/lib/postgresql/` |
| mysql/mariadb | `/etc/mysql/`, `/etc/my.cnf` | `/var/lib/mysql/` |
| nginx | `/etc/nginx/` | `/var/www/`, `/etc/letsencrypt/` |
| docker | `/etc/docker/daemon.json` | `/var/lib/docker/` |
| redis | `/etc/redis/` | `/var/lib/redis/` |
| mosquitto | `/etc/mosquitto/` | `/var/lib/mosquitto/` |
| grafana | `/etc/grafana/grafana.ini` | `/var/lib/grafana/` |
| prometheus | `/etc/prometheus/prometheus.yml` | `/var/lib/prometheus/` |
| *generic* | Detect via systemd unit inspection | Parse from service |

### 2.2 Extract configuration from origin

```bash
ssh <origin_ssh> "cat /path/to/config 2>/dev/null"
ssh <origin_ssh> "systemctl cat <service> 2>/dev/null"
```

### 2.3 Measure data size

```bash
ssh <origin_ssh> "du -sh /var/lib/<service>/ 2>/dev/null"
```

## PHASE 3: IP Cross-Reference Detection

1. Scan configs for IP addresses
2. Load host registry from `private/migration/hosts-registry.nix`
3. For each IP: auto-map if in registry, warn if dependency not migrated, prompt user if unknown
4. Update registry with new mappings

## PHASE 4: Secret Extraction

### 4.1 Identify secrets

Search for `password`, `secret`, `token`, `key`, `credential`, `apikey`, `auth`, SSL private keys, and connection strings.

### 4.2 Create encrypted .age files

Encrypt each secret with BOTH the machine's SSH host key AND the main age key:

```bash
echo "$SECRET" | age -r "$MACHINE_KEY" -r "$MAIN_KEY" > private/nixos/secrets/<machine>/<secret-name>.age
```

Main key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNSkXQmM7HTbNUvGnaiDZpRlCnqHtMPGSlW3cXYBEBf`

### 4.3 Create secrets.nix and register machine

Generate `private/nixos/secrets/<machine>/secrets.nix` with both keys. Run `lxc-add-machine <machine> root@<ip>` to register for global LXC secrets.

## PHASE 5: Generate NixOS Configuration

Create the following files:

1. **`nixos/hardware/<machine>.nix`** -- LXC hardware config with `proxmox-lxc.nix` import
2. **`nixos/machines/<machine>.nix`** -- Service config with NixOS module settings, firewall rules, and agenix secrets
3. **`flake.nix` entry** -- Add `mkProxmoxHost` with appropriate `extraPersistPaths`

Import `${private}/nixos/lxc-management.nix` and set `age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ]`.

For services without native NixOS modules, ask the user: Docker container, systemd service, or manual config.

## PHASE 6: Review and Confirm

Present summary: files to create, detected secrets, IP mappings, data size, persistence paths, and warnings. Get user confirmation.

## PHASE 7: Deploy and Migrate Data

### 7.1 Write files and commit

Stage new files (required for nix flakes). Private submodule files committed separately.

### 7.2 Set up persistence BEFORE first rebuild

This is critical -- services create state during activation. Create bind mounts before rebuild:

```bash
ssh <new_ssh> "mkdir -p /nix/persist/{etc/nixos,etc/ssh,var/log,home,var/lib/<service>}"
```

### 7.3 Deploy

```bash
rebuild -vL <machine>
```

### 7.4 Migrate data

```bash
ssh <origin_ssh> "systemctl stop <service>"
rsync -avz --progress <origin_ssh>:/var/lib/<service>/ <new_ssh>:/nix/persist/var/lib/<service>/
ssh <new_ssh> "chown -R <user>:<group> /nix/persist/var/lib/<service> && systemctl restart <service>"
```

## PHASE 8: Verification

Run service-specific health checks. Compare old vs new where possible. Report results and next steps (DNS update, decommission old container).

## Service-Specific Persistence Paths

| Service | extraPersistPaths |
|-|-|
| postgresql | `[ "/var/lib/postgresql" ]` |
| mysql | `[ "/var/lib/mysql" ]` |
| nginx | `[ "/var/www" "/etc/ssl/private" "/var/lib/letsencrypt" ]` |
| docker | `[ "/var/lib/docker" ]` |
| redis | `[ "/var/lib/redis" ]` |
| mosquitto | `[ "/var/lib/mosquitto" ]` |
| grafana | `[ "/var/lib/grafana" ]` |
| prometheus | `[ "/var/lib/prometheus" ]` |

## Error Handling

| Error | Recovery |
|-|-|
| SSH connection failed | Check connectivity, verify SSH keys |
| Service not found | Use generic systemd inspection, prompt user |
| Config syntax error | Run `nix flake check`, fix manually |
| Secret extraction failed | Prompt user for manual secret entry |
| Data sync failed | Retry rsync, check disk space |
| Health check failed | Check logs: `journalctl -u <service>` |

## Common Pitfalls

- **Agenix identity paths**: LXCs MUST have `age.identityPaths` configured or secrets fail silently
- **SSH key consistency**: The key used for encryption must match the persist key
- **DynamicUser services**: Override with static user for bind mount compatibility
- **First boot**: Access via Proxmox console if SSH fails; check persistence mounts
