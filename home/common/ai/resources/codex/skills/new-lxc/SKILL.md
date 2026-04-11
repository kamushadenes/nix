---
name: new-lxc
description: Create a new NixOS LXC container on Proxmox with impermanence, configured for specified services. Provide services and description in your instructions. Also supports migration mode when called from the migrate-lxc skill.
---

# Create New NixOS LXC Container

Create a new NixOS LXC container on Proxmox with impermanence.

## Usage

Provide in your instructions:
- `services` -- Comma-separated service types (e.g., `postgresql`, `nginx,docker`)
- `description` -- Human-readable description

**Migration mode** (called from `migrate-lxc` skill): receives `--from-migration` with `--ram`, `--cores`, `--disk`, `--vlan`, `--privileged` flags. Skips planning and NixOS config generation.

## Constants

| Item | Value |
|-|-|
| SSH Public Key | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp` |
| Template | `nixos-proxmox-lxc-20260120-234947.tar.xz` |
| Min Disk | 16GB |
| Min RAM | 512MB |
| Min Cores | 1 |
| Storage Options | `ceph-block` (default), `local-lvm` |
| Default VLAN | 6 |
| Proxmox Nodes | pve1: 10.23.5.10, pve2: 10.23.5.11, pve3: 10.23.5.12 |

## PHASE 1: Check Migration Mode

If `--from-migration` is present: extract specs from flags, skip to Phase 4 (still ask for hostname and storage), do NOT generate NixOS config.

For normal invocation: continue with Phase 2.

## PHASE 2: Gather Requirements

Ask the user for:

1. **Hostname** -- machine name for the LXC
2. **Proxmox host** -- pve1 (recommended), pve2, or pve3
3. **Storage** -- ceph-block (recommended) or local-lvm
4. **Specs** -- Minimal (512MB/1core/16GB), Standard (1GB/2cores/32GB), or Custom
5. **VLAN** -- 6 (default) or custom
6. **Privilege mode** -- Unprivileged (recommended) or Privileged (needed for Docker)

## PHASE 3: Generate Plan

Present a summary of what will be created:
- LXC specs (hostname, RAM, cores, disk, VLAN, privileged)
- NixOS configuration files to generate
- Services to configure with persistence paths

Get user approval before proceeding.

## PHASE 4: Create LXC

### 4.1 Create on Proxmox

```bash
VMID=$(ssh root@<proxmox_host> "pvesh get /cluster/nextid")

ssh root@<proxmox_host> "pct create $VMID ceph-files:vztmpl/nixos-proxmox-lxc-20260120-234947.tar.xz \
  --hostname <machine_name> \
  --memory <RAM> \
  --cores <CORES> \
  --rootfs <storage>:<DISK_GB> \
  --net0 name=eth0,bridge=vmbr0,tag=<VLAN>,ip=dhcp \
  --onboot 1 \
  --unprivileged <0_or_1> \
  --features nesting=1 \
  --tags nixos \
  --ssh-public-keys /dev/stdin" <<< "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp"
```

### 4.2 Start and get IP

```bash
ssh root@<proxmox_host> "pct start $VMID"
sleep 10
NEW_IP=$(ssh root@<proxmox_host> "pct exec $VMID -- /run/current-system/sw/bin/ip -4 addr show eth0 | grep -oP 'inet \K[0-9.]+' | head -1")
```

### 4.3 Convert DHCP to static IP

Preserve MAC address, add static IP/gateway to PCT config.

### 4.4 Set up persistence

```bash
ssh root@$NEW_IP "
  mkdir -p /nix/persist/etc/{nixos,ssh}
  mkdir -p /nix/persist/var/log
  mkdir -p /nix/persist/home
  # Service-specific directories based on services argument
  ssh-keygen -t ed25519 -f /nix/persist/etc/ssh/ssh_host_ed25519_key -N ''
  ssh-keygen -t rsa -b 4096 -f /nix/persist/etc/ssh/ssh_host_rsa_key -N ''
  systemd-machine-id-setup --root=/nix/persist
"
```

**For migration mode:** Stop here. Output `VMID` and `NEW_IP`, return to `migrate-lxc` skill.

## PHASE 5: Generate NixOS Configuration (normal mode only)

### 5.1 Hardware config

Create `nixos/hardware/<machine>.nix` with `proxmox-lxc.nix` import, console settings, hostname.

### 5.2 Service config

Create `nixos/machines/<machine>.nix` with service-specific NixOS module configuration.

### 5.3 Machine config with secrets

Create `private/nixos/<machine>.nix` with LXC management import, agenix identity paths, SSH authorized keys.

### 5.4 Update flake.nix

Add `mkProxmoxHost` entry with appropriate `extraPersistPaths`.

## PHASE 6: Deploy (normal mode only)

```bash
git add nixos/hardware/<machine>.nix nixos/machines/<machine>.nix flake.nix
cd private && git add nixos/<machine>.nix && cd ..
rebuild -vL <machine>
```

## PHASE 7: Verify

Run service-specific health checks and report results:

| Service | Health Check |
|-|-|
| postgresql | `sudo -u postgres pg_isready -h localhost` |
| nginx | `nginx -t && curl -sI http://localhost` |
| docker | `docker info` |
| redis | `redis-cli ping` |
| mosquitto | `systemctl is-active mosquitto` |
| grafana | `curl -s http://localhost:3000/api/health` |

## Service-Specific Persistence Paths

| Service | Paths |
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
| Proxmox SSH failed | Check SSH key, verify host is reachable |
| Template not found | Verify: `ssh root@<host> "ls /var/lib/vz/template/cache/"` |
| VMID conflict | Use `pvesh get /cluster/nextid` again |
| No IP assigned | Check VLAN tag, verify DHCP server |
| Persistence setup failed | Access via `pct enter $VMID` |
| Deployment failed | Check `nix flake check`, verify git files staged |
