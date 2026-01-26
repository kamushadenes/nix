---
description: Create a new NixOS LXC container on Proxmox
argument-hint: [services] [description] [--from-migration options]
---

# Create New NixOS LXC Container

Arguments: $ARGUMENTS

Create a new NixOS LXC container on Proxmox with impermanence, configured for the specified services.

## Syntax

```
/new-lxc <services> "<description>"
```

**Examples:**
```bash
/new-lxc postgresql "Database server for production"
/new-lxc "nginx,docker" "Web server with container support"
/new-lxc mqtt "MQTT broker for IoT devices"
```

**Internal migration mode** (called by /migrate-lxc):
```bash
/new-lxc <services> "<description>" --from-migration --ram=<MB> --cores=<N> --disk=<GB> --vlan=<tag> --privileged=<0|1>
```

---

## Constants

| Item | Value |
|------|-------|
| SSH Public Key | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp henrique.goncalves@henrique.goncalves` |
| Template | `nixos-proxmox-lxc-20260120-234947.tar.xz` |
| Min Disk | 16GB |
| Min RAM | 512MB |
| Min Cores | 1 |
| Storage Options | `cts` (default), `local-lvm` |
| Default VLAN | 6 |
| IPv4 | DHCP |
| Onboot | Yes |
| Features | nesting=1 |

---

## PHASE 1: Check for Migration Mode

Parse `$ARGUMENTS` for `--from-migration` flag.

**If `--from-migration` is present:**
- Extract specs from flags: `--ram`, `--cores`, `--disk`, `--vlan`, `--privileged`
- Skip Phases 2-5 (no plan mode, no interactive questions for specs)
- Still ask for hostname and storage (via AskUserQuestion) since these aren't known from origin
- Jump directly to Phase 6 to create the LXC
- **Do NOT generate NixOS config** - /migrate-lxc handles that
- Output only the new LXC's IP address when done

**For normal invocation:** Continue with Phase 2.

---

## PHASE 2: Enter Plan Mode (normal invocation only)

**This command operates in plan mode.** Gather all requirements before creating anything.

---

## PHASE 3: Parse Arguments (normal invocation)

Extract from `$ARGUMENTS`:
- `services` - Comma-separated service types (e.g., `postgresql`, `nginx,docker`)
- `description` - Human-readable description in quotes

---

## PHASE 4: Gather Requirements via AskUserQuestion

**For migration mode:** Only ask 4.1 (hostname) and 4.3 (storage), skip the rest.

### 4.1 Machine Name

Ask: "What should be the hostname for this LXC?"
- Header: "Hostname"
- Options: Let user provide free text (use service name as suggestion)

### 4.2 Proxmox Host (normal invocation only)

Ask: "Which Proxmox host should run this LXC?"
- Options:
  - `10.23.5.10` (pve1) - Recommended
- Header: "PVE Host"

### 4.3 Storage

Ask: "Which storage pool for the LXC?"
- Options:
  - `cts` (Recommended)
  - `local-lvm`
  - Other (specify)
- Header: "Storage"

### 4.4 Specs (normal invocation only)

Ask: "What specifications for the LXC?"
- Options:
  - Minimal (512MB RAM, 1 core, 16GB disk) - Recommended for light services
  - Standard (1GB RAM, 2 cores, 32GB disk) - Good for databases
  - Custom - Specify manually
- Header: "Specs"

If Custom, ask follow-up questions for RAM (MB), cores, disk (GB).

### 4.5 Network (normal invocation only)

Ask: "Which VLAN for this LXC?"
- Options:
  - VLAN 6 (Recommended - default services VLAN)
  - Custom (specify tag)
- Header: "VLAN"

### 4.6 Privileged Mode (normal invocation only)

Ask: "Container privilege mode?"
- Options:
  - Unprivileged (Recommended - more secure)
  - Privileged (needed for some services like Docker)
- Header: "Privilege"

---

## PHASE 5: Generate Plan (normal invocation only)

Present a summary of what will be created:

1. **Proxmox LXC**:
   - Hostname: `<machine_name>`
   - Specs: `<RAM>` MB RAM, `<cores>` cores, `<disk>` GB disk
   - Network: VLAN `<tag>`, IPv4 DHCP
   - Privileged: Yes/No

2. **NixOS Configuration**:
   - `nixos/hardware/<machine>.nix` - Hardware config
   - `nixos/machines/<machine>.nix` - Service config
   - `private/nixos/<machine>.nix` - Network & secrets
   - `flake.nix` entry via `mkProxmoxHost`

3. **Services to configure**: List each service with persistence paths

---

## PHASE 6: Exit Plan Mode (normal invocation only)

Use ExitPlanMode to request user approval.

---

## PHASE 7: Create LXC

**For migration mode:** Jump here directly with passed specs.
**For normal invocation:** Proceed after plan approval.

### 7.1 Create on Proxmox

```bash
# Get next VMID
VMID=$(ssh root@<proxmox_host> "pvesh get /cluster/nextid")

# Create LXC
ssh root@<proxmox_host> "pct create $VMID <storage>:vztmpl/nixos-proxmox-lxc-20260120-234947.tar.xz \
  --hostname <machine_name> \
  --memory <RAM> \
  --cores <CORES> \
  --rootfs <storage>:<DISK_GB> \
  --net0 name=eth0,bridge=vmbr0,tag=<VLAN>,ip=dhcp \
  --onboot 1 \
  --unprivileged <0_or_1> \
  --features nesting=1 \
  --ssh-public-keys /dev/stdin" <<< "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp henrique.goncalves@henrique.goncalves"
```

Note: For `--unprivileged`, use `1` for unprivileged (secure) or `0` for privileged.

### 7.2 Start LXC and get IP

```bash
# Start LXC
ssh root@<proxmox_host> "pct start $VMID"

# Wait for network
sleep 10

# Get IP address
NEW_IP=$(ssh root@<proxmox_host> "pct exec $VMID -- ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \\K[0-9.]+' | head -1")

# If no IP yet, wait and retry
if [ -z "$NEW_IP" ]; then
  sleep 10
  NEW_IP=$(ssh root@<proxmox_host> "pct exec $VMID -- ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \\K[0-9.]+' | head -1")
fi
```

Report: VMID `$VMID`, IP `$NEW_IP`

### 7.3 Set up persistence directories

```bash
ssh root@$NEW_IP "
  # Base persistence structure
  mkdir -p /nix/persist/etc/{nixos,ssh}
  mkdir -p /nix/persist/var/log
  mkdir -p /nix/persist/home

  # Service-specific directories (based on services argument)
  # postgresql: mkdir -p /nix/persist/var/lib/postgresql
  # mysql: mkdir -p /nix/persist/var/lib/mysql
  # nginx: mkdir -p /nix/persist/var/www /nix/persist/etc/ssl/private /nix/persist/var/lib/letsencrypt
  # docker: mkdir -p /nix/persist/var/lib/docker
  # redis: mkdir -p /nix/persist/var/lib/redis
  # mqtt/mosquitto: mkdir -p /nix/persist/var/lib/mosquitto
  # grafana: mkdir -p /nix/persist/var/lib/grafana
  # prometheus: mkdir -p /nix/persist/var/lib/prometheus
  # influxdb: mkdir -p /nix/persist/var/lib/influxdb
  # syncthing: mkdir -p /nix/persist/var/lib/syncthing

  # Generate SSH host keys
  ssh-keygen -t ed25519 -f /nix/persist/etc/ssh/ssh_host_ed25519_key -N ''
  ssh-keygen -t rsa -b 4096 -f /nix/persist/etc/ssh/ssh_host_rsa_key -N ''

  # Machine ID
  systemd-machine-id-setup --root=/nix/persist
"
```

**For migration mode:** Stop here. Output the IP address and return to /migrate-lxc:

```
LXC created successfully.
VMID: $VMID
IP: $NEW_IP
```

---

## PHASE 8: Generate NixOS Configuration (normal invocation only)

**Skip this phase in migration mode** - /migrate-lxc generates its own config.

### 8.1 Create hardware config

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

### 8.2 Create service config

Create `nixos/machines/<machine>.nix` with service-specific NixOS configuration.

Reference the service configuration table from migrate-lxc for each service type.

### 8.3 Create machine config with secrets

Create `private/nixos/<machine>.nix`:

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
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # SSH access
  users.users.root.openssh.authorizedKeys.keys = [ authorizedKey ];
}
```

### 8.4 Update flake.nix

Add to `nixosConfigurations`:

```nix
<machine> = mkProxmoxHost {
  machine = "<machine>";
  hardware = ./nixos/hardware/<machine>.nix;
  role = "minimal";
  extraPersistPaths = [ "/var/lib/<service>" ];  # Service-specific
};
```

---

## PHASE 9: Deploy (normal invocation only)

**Skip this phase in migration mode** - /migrate-lxc handles deployment.

```bash
# Stage files for git (required for nix flakes)
git add nixos/hardware/<machine>.nix nixos/machines/<machine>.nix flake.nix

# Stage private submodule files
cd private && git add nixos/<machine>.nix && cd ..

# Deploy with verbose output and local build
rebuild -vL <machine>
```

---

## PHASE 10: Verification / Output

**For migration mode:** Output only the new LXC IP address for /migrate-lxc to continue:

```
NEW_LXC_IP=<IP_ADDRESS>
```

**For normal invocation:**

### 10.1 Run health checks

Based on configured services, run appropriate health checks:

| Service | Health Check |
|---------|--------------|
| postgresql | `ssh root@$NEW_IP "sudo -u postgres pg_isready -h localhost"` |
| mysql | `ssh root@$NEW_IP "mysqladmin ping -h localhost"` |
| nginx | `ssh root@$NEW_IP "nginx -t && curl -sI http://localhost"` |
| docker | `ssh root@$NEW_IP "docker info"` |
| redis | `ssh root@$NEW_IP "redis-cli ping"` |
| mqtt/mosquitto | `ssh root@$NEW_IP "systemctl is-active mosquitto"` |
| grafana | `ssh root@$NEW_IP "curl -s http://localhost:3000/api/health"` |

### 10.2 Report results

```
LXC Created Successfully!

VMID: <VMID>
IP Address: <IP>
Hostname: <machine>
Services: <services>

Next Steps:
- [ ] Update DNS records to point to new host
- [ ] Configure service-specific settings
- [ ] Monitor logs: journalctl -fu <service>
- [ ] Commit all changes to git
```

---

## Service-Specific Persistence Paths

Reference for `extraPersistPaths` in flake.nix:

| Service | Paths |
|---------|-------|
| postgresql | `[ "/var/lib/postgresql" ]` |
| mysql/mariadb | `[ "/var/lib/mysql" ]` |
| nginx | `[ "/var/www" "/etc/ssl/private" "/var/lib/letsencrypt" ]` |
| docker | `[ "/var/lib/docker" ]` |
| redis | `[ "/var/lib/redis" ]` |
| mqtt/mosquitto | `[ "/var/lib/mosquitto" ]` |
| grafana | `[ "/var/lib/grafana" ]` |
| prometheus | `[ "/var/lib/prometheus" ]` |
| influxdb | `[ "/var/lib/influxdb" ]` |
| syncthing | `[ "/var/lib/syncthing" ]` |
| homeassistant | `[ "/var/lib/hass" ]` |
| nextcloud | `[ "/var/lib/nextcloud" "/var/www/nextcloud/data" ]` |
| jellyfin | `[ "/var/lib/jellyfin" ]` |
| plex | `[ "/var/lib/plexmediaserver" ]` |

---

## Error Handling

| Error | Recovery |
|-------|----------|
| Proxmox SSH failed | Check SSH key, verify host 10.23.5.10 is reachable |
| Template not found | Verify template exists: `ssh root@10.23.5.10 "ls /var/lib/vz/template/cache/"` |
| VMID conflict | Use `pvesh get /cluster/nextid` again |
| No IP assigned | Check VLAN tag, verify DHCP server is running |
| Persistence setup failed | SSH to LXC via Proxmox console: `pct enter $VMID` |
| Deployment failed | Check `nix flake check`, verify git files are staged |

---

Now proceeding with LXC creation using arguments: $ARGUMENTS
