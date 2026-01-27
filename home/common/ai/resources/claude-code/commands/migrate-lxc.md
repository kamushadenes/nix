---
description: Migrate LXC container to NixOS with impermanence
argument-hint: [origin-ssh] [new-ssh] [service-type] [description]
---

# Migrate LXC Container to NixOS

Arguments: $ARGUMENTS

Migrate a non-NixOS LXC container to NixOS with impermanence, handling configuration extraction, secrets via agenix, data migration, and cross-host IP reference resolution.

## Syntax

```
/migrate-lxc <origin-ssh> <new-ssh|new> <service-type> "<description>"
```

**Examples:**
```bash
# Migrate to existing NixOS LXC
/migrate-lxc root@old-postgres.local root@postgres.hyades.io postgresql "Production PostgreSQL database"
/migrate-lxc admin@web-01.local root@web-01.hyades.io nginx "Main reverse proxy"
/migrate-lxc root@docker-host.local root@containers.hyades.io docker "Docker host with Portainer"

# Create new LXC and migrate (use "new" as second argument)
/migrate-lxc root@old-mqtt.local new mqtt "MQTT broker for IoT"
/migrate-lxc root@old-db.local new postgresql "Production database"
```

When `new_ssh` is `"new"`, a new LXC container is created via `/new-lxc` before migration.

---

## Constants

| Item | Value |
|------|-------|
| Proxmox Nodes | pve1: 10.23.5.10 (main), pve2: 10.23.5.11, pve3: 10.23.5.12 |

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

**Exception:** If `new_ssh` is `"new"`, skip validation of new host and proceed to Phase 1.5.

---

## PHASE 1.4: Tag Existing LXC (when target is existing)

If `new_ssh` is NOT `"new"`, find and tag the existing container with "nixos".

### 1.4.1 Find which Proxmox node hosts the target container

```bash
# Proxmox nodes
PVE_NODES="pve1:10.23.5.10 pve2:10.23.5.11 pve3:10.23.5.12"

# Extract target hostname from new_ssh (e.g., root@postgres.hyades.io -> postgres)
TARGET_HOSTNAME=$(echo "<new_ssh>" | sed 's/.*@//' | sed 's/\..*//')

# Find container across all nodes
for node_spec in $PVE_NODES; do
  node_name="${node_spec%:*}"
  node_ip="${node_spec#*:}"
  TARGET_VMID=$(ssh root@$node_ip "pct list 2>/dev/null | grep -E '$TARGET_HOSTNAME' | awk '{print \$1}'" 2>/dev/null)
  if [[ -n "$TARGET_VMID" ]]; then
    TARGET_PVE_HOST="$node_ip"
    break
  fi
done
```

### 1.4.2 Add nixos tag to the container

```bash
if [[ -n "$TARGET_VMID" ]]; then
  # Get existing tags
  EXISTING_TAGS=$(ssh root@$TARGET_PVE_HOST "pct config $TARGET_VMID | grep -oP '^tags: \K.*'" 2>/dev/null || echo "")

  # Add nixos tag if not already present
  if [[ ! "$EXISTING_TAGS" =~ nixos ]]; then
    if [[ -n "$EXISTING_TAGS" ]]; then
      NEW_TAGS="${EXISTING_TAGS};nixos"
    else
      NEW_TAGS="nixos"
    fi
    ssh root@$TARGET_PVE_HOST "pct set $TARGET_VMID --tags '$NEW_TAGS'"
    echo "Added 'nixos' tag to container $TARGET_HOSTNAME (VMID: $TARGET_VMID)"
  fi
fi
```

Continue to Phase 2.

---

## PHASE 1.5: Create New LXC (when target is "new")

If the second argument is `"new"`, create a new LXC container by delegating to `/new-lxc`.

### 1.5.1 Find which Proxmox node hosts the origin container

Query ALL Proxmox nodes to find where the container exists:

```bash
# Proxmox nodes (pveNodes from flake.nix)
PVE_NODES="pve1:10.23.5.10 pve2:10.23.5.11 pve3:10.23.5.12"

# Extract origin hostname from origin_ssh (e.g., root@old-mqtt.local -> old-mqtt)
ORIGIN_HOSTNAME=$(echo "<origin_ssh>" | sed 's/.*@//' | sed 's/\..*//')

# Find container across all nodes
for node_spec in $PVE_NODES; do
  node_name="${node_spec%:*}"
  node_ip="${node_spec#*:}"
  VMID=$(ssh root@$node_ip "pct list 2>/dev/null | grep -E '$ORIGIN_HOSTNAME' | awk '{print \$1}'" 2>/dev/null)
  if [[ -n "$VMID" ]]; then
    PVE_HOST="$node_ip"
    PVE_NODE="$node_name"
    break
  fi
done

if [[ -z "$VMID" ]]; then
  echo "ERROR: Container $ORIGIN_HOSTNAME not found on any Proxmox node"
  exit 1
fi

echo "Found container $ORIGIN_HOSTNAME (VMID: $VMID) on $PVE_NODE ($PVE_HOST)"
```

### 1.5.2 Fetch specs from origin LXC

Query the discovered Proxmox node for container specs:

```bash
# Get specs from the node where container was found
ORIGIN_RAM=$(ssh root@$PVE_HOST "pct config $VMID | grep memory | awk '{print \$2}'")
ORIGIN_CORES=$(ssh root@$PVE_HOST "pct config $VMID | grep cores | awk '{print \$2}'")
ORIGIN_DISK=$(ssh root@$PVE_HOST "pct config $VMID | grep rootfs | grep -oP 'size=\K[0-9]+'")
ORIGIN_VLAN=$(ssh root@$PVE_HOST "pct config $VMID | grep net0 | grep -oP 'tag=\K[0-9]+'")
ORIGIN_UNPRIVILEGED=$(ssh root@$PVE_HOST "pct config $VMID | grep unprivileged | awk '{print \$2}'")
```

**Note**: Container IPs stay the same after migration (MAC address preserved = same DHCP lease).

### 1.5.3 Calculate final specs with minimums

Apply minimum values to ensure adequate resources:

| Spec | Value |
|------|-------|
| RAM | max(512, ORIGIN_RAM) MB |
| Cores | max(1, ORIGIN_CORES) |
| Disk | max(16, ORIGIN_DISK) GB |
| VLAN | ORIGIN_VLAN (copy from origin) |
| Privileged | 1 if ORIGIN_UNPRIVILEGED=0, else 0 |

### 1.5.4 Invoke /new-lxc with --from-migration flag

Execute the `/new-lxc` command in migration mode, passing specs as flags:

```bash
# /new-lxc will:
# - Ask for hostname and storage (via AskUserQuestion)
# - Create the LXC with passed specs
# - Set up persistence directories
# - Return the new IP address
```

The /new-lxc command is invoked internally with these flags:
- `--from-migration` - Signal migration mode (skip plan mode, skip NixOS config generation)
- `--ram=<calculated_ram>`
- `--cores=<calculated_cores>`
- `--disk=<calculated_disk>`
- `--vlan=<origin_vlan>`
- `--privileged=<0_or_1>`

### 1.5.5 Get new LXC IP from /new-lxc output

After /new-lxc completes, it outputs the new LXC's IP address. Parse this and update:

```bash
new_ssh="root@<NEW_IP>"
```

### 1.5.6 Validate new LXC connectivity

```bash
# Test new host connectivity and verify it's NixOS
ssh -o ConnectTimeout=5 -o BatchMode=yes $new_ssh "hostname && nixos-version"
```

Continue to Phase 2 with the newly created LXC.

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

# Get the machine's SSH host key (after LXC is created)
MACHINE_KEY=$(ssh <new_ssh> "cat /nix/persist/etc/ssh/ssh_host_ed25519_key.pub | cut -d' ' -f1,2")

# Main age key (always the same)
MAIN_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNSkXQmM7HTbNUvGnaiDZpRlCnqHtMPGSlW3cXYBEBf"

# Encrypt with BOTH keys - machine key for LXC decryption, main key for management
echo "$SECRET" | age -r "$MACHINE_KEY" -r "$MAIN_KEY" > private/nixos/secrets/<machine>/<secret-name>.age
```

### 4.3 Create secrets.nix

Generate `private/nixos/secrets/<machine>/secrets.nix`:

**IMPORTANT:** Include BOTH the machine's SSH host key AND the main age key as recipients. This allows:
- The LXC to decrypt secrets using its SSH host key
- Workstations to re-encrypt/manage secrets using the main age key

```nix
let
  # Machine's SSH host key (get from /nix/persist/etc/ssh/ssh_host_ed25519_key.pub on the LXC)
  machineKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  # Main age key (always the same across all secrets)
  mainKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNSkXQmM7HTbNUvGnaiDZpRlCnqHtMPGSlW3cXYBEBf";
in
{
  "db-password.age".publicKeys = [ machineKey mainKey ];
  "ssl-key.age".publicKeys = [ machineKey mainKey ];
}
```

### 4.4 Register Machine for Global LXC Secrets

Run the `lxc-add-machine` script to add the new machine to the global LXC key infrastructure:

```bash
# Add machine to lxc-management secrets (updates secrets.nix and re-encrypts key)
lxc-add-machine <machine> root@<ip>
```

This script:
1. Fetches the machine's SSH host key
2. Adds it to `private/nixos/secrets/lxc-management/secrets.nix`
3. Re-encrypts `lxc-management.pem.age` with all LXC keys

**Two-Tier Secret Architecture:**
- **Machine-specific secrets**: `machineKey + mainKey` - decrypted via SSH host key
- **Global LXC secrets**: `lxcManagementKey + mainKey` - decrypted via shared key deployed to all LXCs

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

### 5.3 Create machine config with secrets

Create `nixos/machines/<machine>.nix`:

```nix
# Machine configuration for <machine>
# <description>
{ config, lib, pkgs, private, ... }:

let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp";
in
{
  # Import LXC management module for global secrets support
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # CRITICAL: Agenix identity paths for secret decryption
  # SSH host key for machine-specific secrets; lxc-management.nix adds global key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

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
  role = "minimal";  # Familiar shell environment for service containers
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

### 7.3 Set up persistence directories BEFORE first rebuild (CRITICAL)

**This step MUST be done before the first `rebuild`.** Services create their state during initial activation. If persistence directories don't exist as bind mounts yet, data goes to ephemeral storage and is lost.

```bash
# SSH to new container (may need console access for fresh containers)
ssh <new_ssh>

# Create base persistence structure
mkdir -p /nix/persist/etc/nixos
mkdir -p /nix/persist/etc/ssh
mkdir -p /nix/persist/var/log
mkdir -p /nix/persist/home

# Create service-specific persistence directory
mkdir -p /nix/persist/var/lib/<service>

# Generate SSH host keys (required for sshd)
ssh-keygen -t ed25519 -f /nix/persist/etc/ssh/ssh_host_ed25519_key -N ""
ssh-keygen -t rsa -b 4096 -f /nix/persist/etc/ssh/ssh_host_rsa_key -N ""

# Copy machine-id from origin (preserves DHCP identity for stable IPs)
# The machine-id is used by systemd-networkd to generate the DUID,
# which DHCP servers use to track leases. Keeping it ensures same IP.
scp <origin_ssh>:/etc/machine-id /nix/persist/etc/machine-id 2>/dev/null || \
  systemd-machine-id-setup --root=/nix/persist  # Fallback if origin unavailable

# Symlink machine-id so it's available immediately
ln -sf /nix/persist/etc/machine-id /etc/machine-id

# Create bind mounts manually for first boot
mount --bind /nix/persist/etc/nixos /etc/nixos
mount --bind /nix/persist/etc/ssh /etc/ssh
mount --bind /nix/persist/var/log /var/log
mount --bind /nix/persist/home /home
mount --bind /nix/persist/var/lib/<service> /var/lib/<service>
```

**Why this matters:**
- On first nixos-rebuild, the service activation scripts run
- Services like atuin, postgresql, etc. initialize their data directories
- Without bind mounts in place, this data goes to tmpfs
- After reboot, the persistence module creates bind mounts, but the data is gone

### 7.4 Deploy to new container

```bash
rebuild <machine>
```

### 7.5 Generate data migration commands

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

### 7.6 Execute migration

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

---

## Common Pitfalls & Solutions

### Agenix Identity Paths (CRITICAL for Secrets)

LXCs using agenix secrets **MUST** have `age.identityPaths` configured. Without this, agenix cannot find the key to decrypt secrets.

**In the machine config** (`nixos/machines/<machine>.nix`):
```nix
{
  # Agenix identity paths for secret decryption (uses SSH host key)
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Then your secrets...
  age.secrets."my-secret" = {
    file = "${private}/nixos/secrets/<machine>/my-secret.age";
  };
}
```

**Critical: SSH key consistency.** The SSH host key used for encryption (in `secrets.nix`) must match the key at the identity path:

1. **Encrypt secrets with the persisted key** - Use the public key from `/nix/persist/etc/ssh/ssh_host_ed25519_key.pub`
2. **Or sync keys after LXC creation** - If the LXC was created with a different key, copy it to the persist location

**Symptoms of missing/mismatched identity:**
```
age: error: no identity matched any of the recipients
chmod: cannot access '/run/agenix.d/1/secret-name.tmp': No such file or directory
```

**Fix for key mismatch:**
```bash
# Check which key secrets.nix expects
cat private/nixos/secrets/<machine>/secrets.nix | grep ssh-ed25519

# Check what key is on the LXC
ssh root@<machine> "cat /nix/persist/etc/ssh/ssh_host_ed25519_key.pub"

# If they don't match, either:
# 1. Copy the correct key to persist:
ssh root@<machine> "cp /etc/ssh/ssh_host_ed25519_key* /nix/persist/etc/ssh/"

# 2. Or re-encrypt secrets with the persist key (update secrets.nix with new pubkey)
```

### Persistence Module Issues

The `proxmox.persistence` module creates bind mounts from `/nix/persist/*`. Key points:

1. **Directories are auto-created** - The `create-persist-dirs.service` runs early (before `local-fs-pre.target`) to create all persist directories
2. **SSH host keys are auto-generated** - If `/nix/persist/etc/ssh/` is empty, host keys are generated automatically
3. **Machine-id is auto-generated** - Required for systemd-journald

If persistence fails:
```bash
# Check if create-persist-dirs ran
systemctl status create-persist-dirs

# Check mount status
mount | grep /nix/persist

# Manual recovery
mkdir -p /nix/persist/{etc/nixos,etc/ssh,var/log,home}
ssh-keygen -A -f /nix/persist  # Generate host keys
```

### SSH Access Issues

**PermitRootLogin**: The `security.nix` sets `PermitRootLogin = "no"` by default. For minimal role containers that need root SSH access for deployment:

- The `minimal.nix` module sets `PermitRootLogin = "prohibit-password"` via `lib.mkForce`
- Authorized keys are configured for both `root` and `kamushadenes` users

**Socket activation**: NixOS uses socket-activated SSH (`sshd.socket` + `sshd@.service`), not a monolithic `sshd.service`. To check:
```bash
systemctl status sshd.socket
systemctl list-units --type=service | grep sshd
```

**SFTP Subsystem**: The `nix-remote-setup` script uses `scp` which requires the SFTP subsystem. If you see `subsystem request failed on channel 0`, add to `/etc/ssh/sshd_config`:
```bash
SFTP=$(find /nix/store -name sftp-server -type f | head -1)
echo "Subsystem sftp $SFTP" >> /etc/ssh/sshd_config
systemctl restart sshd.socket
```

**Deployment user**: For minimal role containers, add `"user": "root"` to the node config in `private/nodes.json`:
```json
"<machine>": {
  "type": "nixos",
  "role": "minimal",
  "user": "root",
  "targetHosts": ["<ip>", "<hostname>"]
}
```

### DynamicUser and Bind Mounts

Services using `DynamicUser=true` (like atuin) don't work well with bind mounts due to permission issues. The dynamic user can't access directories owned by root.

**Solution**: Override the systemd unit to use a static user:
```nix
# Create static user
users.users.<service> = {
  isSystemUser = true;
  group = "<service>";
  home = "/var/lib/<service>";
};
users.groups.<service> = { };

# Override systemd unit
systemd.services.<service> = {
  serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "<service>";
    Group = "<service>";
    StateDirectory = "<service>";
    StateDirectoryMode = "0700";
  };
};
```

### Service Database Configuration

**PostgreSQL vs SQLite**: Many NixOS service modules default to `database.createLocally = true` which sets up PostgreSQL. For SQLite:

```nix
services.<service> = {
  enable = true;
  database = {
    createLocally = false;  # Don't use PostgreSQL
    uri = "sqlite:///var/lib/<service>/data.db";
  };
};
```

Check service unit for `Requires=postgresql.target` which indicates PostgreSQL dependency:
```bash
systemctl cat <service>.service | grep -i postgres
```

### First Boot Issues

On first deployment, if the LXC becomes inaccessible:

1. **Access via Proxmox console** - Don't rely on SSH for first boot
2. **Check persistence mounts** - `mount | grep persist`
3. **Check SSH** - `systemctl status sshd.socket`, check `/etc/ssh/` for host keys
4. **Check service logs** - `journalctl -u <service>` (may be empty if /var/log bind mount failed)

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
