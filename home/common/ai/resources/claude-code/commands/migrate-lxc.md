---
description: Migrate LXC container to NixOS with impermanence
argument-hint: [origin-ssh] [new-ssh] [service-type] [description]
---

# Migrate LXC Container to NixOS

Arguments: $ARGUMENTS

Migrate a non-NixOS LXC container to NixOS with impermanence, handling configuration extraction, secrets via agenix, data migration, and cross-host IP reference resolution.

## Syntax

```
/migrate-lxc <origin-ssh> <new-ssh> <service-type> "<description>"
```

**Examples:**
```bash
/migrate-lxc root@old-postgres.local root@postgres.hyades.io postgresql "Production PostgreSQL database"
/migrate-lxc admin@web-01.local root@web-01.hyades.io nginx "Main reverse proxy"
/migrate-lxc root@docker-host.local root@containers.hyades.io docker "Docker host with Portainer"
```

---

## PHASE 1: Parse & Validate Arguments

### 1.1 Parse the arguments

Extract from `$ARGUMENTS`:
- `origin_ssh` - First argument (e.g., `root@old-host.local`)
- `new_ssh` - Second argument (e.g., `root@new-host.hyades.io`)
- `service_type` - Third argument (e.g., `postgresql`, `nginx`, `docker`)
- `description` - Remaining text in quotes

### 1.2 Derive machine name

Extract hostname from `new_ssh`:
- `root@web-01.hyades.io` → `web-01`
- If the target is an IP address, prompt user for machine name

### 1.3 Validate connectivity

Test SSH connections to both hosts:

```bash
# Test origin connectivity
ssh -o ConnectTimeout=5 -o BatchMode=yes <origin_ssh> "hostname && uname -a && cat /etc/os-release 2>/dev/null | head -5"

# Test new host connectivity and verify it's NixOS
ssh -o ConnectTimeout=5 -o BatchMode=yes <new_ssh> "hostname && nixos-version"
```

If either fails, report the error and ask user to fix before proceeding.

---

## PHASE 2: Service Discovery

### 2.1 Detect service configuration

Based on `service_type`, identify config and data paths:

| Service | Config Paths | Data Paths |
|---------|--------------|------------|
| postgresql | `/etc/postgresql/*/main/`, `/var/lib/postgresql/*/main/*.conf` | `/var/lib/postgresql/` |
| mysql/mariadb | `/etc/mysql/`, `/etc/my.cnf`, `/etc/my.cnf.d/` | `/var/lib/mysql/` |
| nginx | `/etc/nginx/` | `/var/www/`, `/etc/ssl/`, `/etc/letsencrypt/` |
| docker | `/etc/docker/daemon.json` | `/var/lib/docker/` |
| redis | `/etc/redis/redis.conf`, `/etc/redis/` | `/var/lib/redis/` |
| plex | `/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml` | `/var/lib/plexmediaserver/` |
| jellyfin | `/etc/jellyfin/`, `/var/lib/jellyfin/config/` | `/var/lib/jellyfin/` |
| homeassistant | `/etc/homeassistant/`, `~/.homeassistant/`, `/var/lib/hass/` | Same as config |
| nextcloud | `/var/www/nextcloud/config/config.php` | `/var/www/nextcloud/data/` |
| syncthing | `~/.config/syncthing/config.xml` | Sync folders from config |
| mosquitto | `/etc/mosquitto/mosquitto.conf`, `/etc/mosquitto/conf.d/` | `/var/lib/mosquitto/` |
| grafana | `/etc/grafana/grafana.ini` | `/var/lib/grafana/` |
| prometheus | `/etc/prometheus/prometheus.yml` | `/var/lib/prometheus/` |
| influxdb | `/etc/influxdb/influxdb.conf` | `/var/lib/influxdb/` |
| *generic* | Detect via systemd unit inspection | Parse from service |

### 2.2 Extract configuration from origin

```bash
# For known services
ssh <origin_ssh> "cat /path/to/config 2>/dev/null"

# For unknown services, inspect systemd unit
ssh <origin_ssh> "systemctl cat <service> 2>/dev/null"
ssh <origin_ssh> "systemctl show <service> --property=ExecStart,WorkingDirectory,Environment"
```

Store extracted configs locally for analysis.

### 2.3 Measure data size

```bash
ssh <origin_ssh> "du -sh /var/lib/<service>/ 2>/dev/null"
```

Report estimated transfer size to user.

---

## PHASE 3: IP Cross-Reference Detection

### 3.1 Scan configs for IP addresses

Search all extracted configs for IP patterns:

```bash
grep -rhoE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' <extracted-configs> | sort -u
```

### 3.2 Load host registry

Read `private/migration/hosts-registry.nix`:

```nix
{
  # "old-ip" = "new-hostname";
  "192.168.1.50" = "postgres.hyades.io";
  "192.168.1.51" = "redis.hyades.io";
}
```

### 3.3 Resolve each detected IP

For each IP found in configs:

1. **If in registry with hostname** → Auto-map to new hostname
2. **If in registry with `null`** → Warn "dependency not yet migrated"
3. **If not in registry** → Prompt user:
   - "Found IP `192.168.1.52` in config. What is this host?"
   - Options:
     - Map to existing NixOS host (provide hostname)
     - Will migrate later (mark as `null`)
     - External service (keep as IP)
     - Localhost/internal (ignore)

### 3.4 Update registry

Add new mappings discovered during this migration to `private/migration/hosts-registry.nix`.

---

## PHASE 4: Secret Extraction

### 4.1 Identify secrets in configs

Search for patterns indicating secrets:
- Keywords: `password`, `secret`, `token`, `key`, `credential`, `apikey`, `auth`
- SSL private keys: `-----BEGIN.*PRIVATE KEY-----`
- Database connection strings: `postgres://`, `mysql://`, `redis://`
- Hashed passwords (to preserve, not extract)

### 4.2 Create encrypted .age files

For each identified secret:

```bash
# Extract secret value
SECRET=$(ssh <origin_ssh> "grep -oP 'password=\K.*' /path/to/config")

# Encrypt with age using the project's SSH key
echo "$SECRET" | age -r "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNSkXQmM7HTbNUvGnaiDZpRlCnqHtMPGSlW3cXYBEBf" > private/nixos/secrets/<machine>/<secret-name>.age
```

### 4.3 Create secrets.nix

Generate `private/nixos/secrets/<machine>/secrets.nix`:

```nix
let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNSkXQmM7HTbNUvGnaiDZpRlCnqHtMPGSlW3cXYBEBf";
in
{
  "db-password.age".publicKeys = [ key ];
  "ssl-key.age".publicKeys = [ key ];
}
```

---

## PHASE 5: Generate NixOS Configuration

### 5.1 Create hardware config

Create `nixos/hardware/<machine>.nix`:

```nix
# Hardware configuration for <machine>
# LXC container running on Proxmox
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  boot.isContainer = true;

  # Console configuration for Proxmox LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "<machine>";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

### 5.2 Create service config

**ALWAYS** create `nixos/machines/<machine>.nix`:

For services **with** native NixOS module support:

```nix
# Service configuration for <machine>
# <description>
{ config, lib, pkgs, ... }:

{
  services.<service> = {
    enable = true;
    # ... converted from extracted config
  };

  # Service-specific firewall rules
  networking.firewall.allowedTCPPorts = [ <port> ];
}
```

For services **without** native NixOS module support, prompt user:
- "Service `<type>` has no native NixOS module. How should it be deployed?"
- Options:
  1. **Docker container** - Generate `virtualisation.oci-containers` config
  2. **systemd service** - Create custom systemd unit
  3. **Manual** - Create placeholder, user will configure

### 5.3 Create private config

Create `private/nixos/<machine>.nix`:

```nix
# Private configuration for <machine>
# Contains networking details and agenix secrets
{ config, lib, pkgs, private, ... }:

let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp";
in
{
  # Agenix secrets
  age.secrets = {
    "<secret-name>" = {
      file = "${private}/nixos/secrets/<machine>/<secret-name>.age";
      owner = "<service-user>";
      mode = "0400";
    };
  };

  # SSH access
  users.users.root.openssh.authorizedKeys.keys = [ authorizedKey ];

  # Network configuration (if static IP required)
  # networking.interfaces.eth0.ipv4.addresses = [{ address = "x.x.x.x"; prefixLength = 24; }];
}
```

### 5.4 Update flake.nix

Add to `nixosConfigurations`:

```nix
<machine> = mkProxmoxHost {
  machine = "<machine>";
  hardware = ./nixos/hardware/<machine>.nix;
  role = "headless";
  extraPersistPaths = [ "/var/lib/<service>" ];  # Service-specific
};
```

---

## PHASE 6: Review & Confirm

### 6.1 Present summary

Display to user:
- Files to be created (with paths)
- Detected secrets (names only, not values)
- IP mappings to be applied
- Data migration size estimate
- Persistence paths configured
- Any warnings (unmigrated dependencies, manual steps needed)

### 6.2 Get user confirmation

Ask: "Ready to create these files and proceed with deployment? (y/n)"

If no, allow user to specify changes before proceeding.

---

## PHASE 7: Deploy & Migrate Data

### 7.1 Create all files

After user approval, write all generated files using the Write tool.

### 7.2 Commit new files

Stage new files for git (required for nix flakes):

```bash
git add nixos/hardware/<machine>.nix
git add nixos/machines/<machine>.nix
git add flake.nix
# Private submodule files committed separately
cd private && git add nixos/<machine>.nix nixos/secrets/<machine>/ && cd ..
```

### 7.3 Deploy to new container

```bash
rebuild <machine>
```

### 7.4 Generate data migration commands

Present migration commands (don't execute without confirmation):

```bash
# 1. Stop service on origin (optional - for consistency)
ssh <origin_ssh> "systemctl stop <service>"

# 2. Sync data to new host
rsync -avz --progress <origin_ssh>:/var/lib/<service>/ <new_ssh>:/nix/persist/var/lib/<service>/

# 3. Fix ownership on new host
ssh <new_ssh> "chown -R <user>:<group> /nix/persist/var/lib/<service>"

# 4. Restart service on new host
ssh <new_ssh> "systemctl restart <service>"

# 5. Optionally restart origin (until cutover confirmed)
ssh <origin_ssh> "systemctl start <service>"
```

### 7.5 Execute migration

Ask user to confirm each step or proceed automatically.

---

## PHASE 8: Verification

### 8.1 Run health checks

| Service | Health Check Command |
|---------|---------------------|
| postgresql | `ssh <new_ssh> "sudo -u postgres pg_isready -h localhost"` |
| mysql | `ssh <new_ssh> "mysqladmin ping -h localhost"` |
| nginx | `ssh <new_ssh> "nginx -t && curl -sI http://localhost"` |
| docker | `ssh <new_ssh> "docker info"` |
| redis | `ssh <new_ssh> "redis-cli ping"` |
| grafana | `ssh <new_ssh> "curl -s http://localhost:3000/api/health"` |

### 8.2 Compare old vs new

Where possible, verify functional equivalence:
- PostgreSQL: Compare row counts on key tables
- Nginx: Compare HTTP response headers
- Docker: Compare running container lists

### 8.3 Report results

Summarize:
- Health check results (pass/fail)
- Any warnings or issues detected
- Next steps (DNS update, old container decommission)

---

## Service-Specific Persistence Paths

Reference for `extraPersistPaths` in flake.nix:

| Service | Paths |
|---------|-------|
| postgresql | `[ "/var/lib/postgresql" ]` |
| mysql | `[ "/var/lib/mysql" ]` |
| nginx | `[ "/var/www" "/etc/ssl/private" "/var/lib/letsencrypt" ]` |
| docker | `[ "/var/lib/docker" ]` |
| redis | `[ "/var/lib/redis" ]` |
| plex | `[ "/var/lib/plexmediaserver" ]` |
| jellyfin | `[ "/var/lib/jellyfin" ]` |
| homeassistant | `[ "/var/lib/hass" ]` |
| nextcloud | `[ "/var/lib/nextcloud" "/var/www/nextcloud/data" ]` |
| syncthing | `[ "/var/lib/syncthing" ]` |
| mosquitto | `[ "/var/lib/mosquitto" ]` |
| grafana | `[ "/var/lib/grafana" ]` |
| prometheus | `[ "/var/lib/prometheus" ]` |
| influxdb | `[ "/var/lib/influxdb" ]` |

---

## Error Handling

| Error | Recovery |
|-------|----------|
| SSH connection failed | Check connectivity, verify SSH keys configured |
| Service not found | Use generic systemd inspection, prompt user for paths |
| Config syntax error | Run `nix flake check`, identify and fix manually |
| Secret extraction failed | Prompt user for manual secret entry |
| Data sync failed | Retry rsync, check disk space, verify permissions |
| Health check failed | Check systemd logs: `journalctl -u <service>` |

### Rollback procedure

If migration fails:

```bash
# Revert flake.nix changes
git checkout -- flake.nix

# Remove generated files
rm nixos/hardware/<machine>.nix
rm nixos/machines/<machine>.nix

# Remove private files
cd private
git checkout -- nixos/<machine>.nix
rm -rf nixos/secrets/<machine>/
cd ..

# Restart origin service
ssh <origin_ssh> "systemctl start <service>"
```

---

## Files Created by This Command

1. `nixos/hardware/<machine>.nix` - LXC hardware configuration
2. `nixos/machines/<machine>.nix` - Service configuration (ALWAYS created)
3. `private/nixos/<machine>.nix` - Networking and secrets configuration
4. `private/nixos/secrets/<machine>/` - Directory with encrypted .age files
5. `private/nixos/secrets/<machine>/secrets.nix` - Agenix secret declarations
6. Updated `flake.nix` - New nixosConfigurations entry
7. Updated `private/migration/hosts-registry.nix` - IP mappings

---

## Post-Migration Checklist

After successful migration:

- [ ] Verify service is responding correctly
- [ ] Update DNS records to point to new host
- [ ] Update any dependent services with new IP/hostname
- [ ] Monitor logs for errors: `journalctl -fu <service>`
- [ ] Plan decommission of old container
- [ ] Document migration in project notes
- [ ] Commit all changes to git

---

Now proceeding with migration using arguments: $ARGUMENTS
