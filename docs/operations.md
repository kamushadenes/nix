# Operations Runbook

This document provides comprehensive, step-by-step procedures for managing and
maintaining the Nix configuration across all 27 systems. It serves as the
definitive reference for daily operations, machine provisioning, secrets
management, and troubleshooting.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Adding a New Proxmox LXC Container](#adding-a-new-proxmox-lxc-container)
3. [Adding a New Darwin Machine](#adding-a-new-darwin-machine)
4. [Secrets Management](#secrets-management)
5. [Proxmox Image Workflows](#proxmox-image-workflows)
6. [Binary Cache Management](#binary-cache-management)
7. [File Synchronization (Mutagen)](#file-synchronization-mutagen)
8. [Troubleshooting Procedures](#troubleshooting-procedures)
9. [Remote Machine Setup](#remote-machine-setup)

---

## Daily Operations

The primary tool for all deployment tasks is the `rebuild` command, a custom
Python-based wrapper around `nh`, `nixos-rebuild`, and `darwin-rebuild`.

### Rebuilding the Current Machine

To apply changes to the machine you are currently using:

```bash
rebuild
```

This automatically:

- Detects the hostname (using `scutil` on macOS or `socket.gethostname` on
  Linux).
- Includes the `--impure` flag (required for private submodule access via
  `builtins.fetchGit`).
- Uses `nh` for a better rebuild experience (showing diffs and progress).
- Decrypts the binary cache signing key if it's missing.

### Deploying to a Remote Machine

To deploy to a single remote target:

```bash
rebuild aether
```

By default, this performs a **pre-build + remote activate** workflow:

1. **Local Pre-build**: Builds the system toplevel locally to populate the
   binary cache.
2. **Cache Upload**: The `post-build-hook` automatically uploads the closure to
   `ncps.hyades.io`.
3. **Remote Activation**: SSHes into the remote machine, pulls the latest
   config, and activates the new generation, fetching pre-built binaries from
   the cache.

### Deploying to a Remote LXC

For LXC containers, it is often faster to build locally and push the closure via
SSH:

```bash
rebuild -vL moltbot
```

- `-v`: Streams output in real-time (prevents SSH timeouts on long builds).
- `-L`: Builds locally and pushes the closure to the remote via SSH.
- **RAM Boost**: For LXCs with `pveNode` defined in `nodes.json`, `rebuild`
  temporarily increases RAM by 4GiB and CPU by 2 cores on the Proxmox host
  during the build to prevent OOM errors.

### Deploying to All Machines of a Type

You can use tags to target groups of machines:

```bash
rebuild @nixos    # All NixOS machines
rebuild @darwin   # All Darwin machines
rebuild @headless # All headless machines
rebuild @workstation # All workstation machines
```

### Parallel Deployment

To deploy to multiple machines simultaneously:

```bash
rebuild -p @darwin   # Parallel deploy to all Darwin machines
rebuild -pa          # Parallel deploy to ALL machines
```

### Dry Run

To see what would be deployed without executing any changes:

```bash
rebuild -n @nixos
```

### Listing Nodes and Tags

To see all configured nodes, their roles, and available tags:

```bash
rebuild --list
```

---

## Adding a New Proxmox LXC Container

### 1. Create the LXC on Proxmox

Create the container on Proxmox using the NixOS LXC template.

- **Unprivileged**: Yes
- **Nesting**: Enabled (required for `nix-daemon`)
- **Features**: `fuse=1,nesting=1`

### 2. Create Hardware Configuration

Create `nixos/hardware/<name>.nix`. Use the following boilerplate for LXC
containers:

```nix
{ machine, ... }:
{
  imports = [
    ./proxmox/lxc.nix
  ];

  # Networking configuration
  networking.hostName = machine;
}
```

### 3. Create Machine Configuration

Create `nixos/machines/<name>.nix`. A minimal configuration looks like this:

```nix
{ ... }:
{
  # Machine-specific services and overrides
  services.openssh.enable = true;
}
```

### 4. Add to flake.nix

Register the new host in `flake.nix` using the `mkProxmoxHost` helper:

```nix
nixosConfigurations = {
  # ... existing hosts
  new-lxc = mkProxmoxHost {
    machine = "new-lxc";
    hardware = ./nixos/hardware/new-lxc.nix;
    role = "minimal"; # or "headless"
    extraPersistPaths = [ "/var/lib/my-service" ];
  };
};
```

### 5. Persistence Model

All LXCs use an **ephemeral tmpfs root** with **bind-mounted persistence** from
`/nix/persist`.

- **Base Paths**: `/etc/nixos`, `/var/lib/systemd`, `/var/log`, `/home`.
- **Extra Paths**: Defined in `mkProxmoxHost` via `extraPersistPaths`.
- **Activation**: The `create-persist-dirs` service runs early to create
  directories and generate SSH host keys if missing.

### 6. Register with agenix

Use the `lxc-add-machine` script to fetch the machine's SSH host key and add it
to the secrets recipients:

```bash
lxc-add-machine <name> <ssh-target>
# Example: lxc-add-machine atuin root@10.23.23.124
```

This script:

1. Fetches the SSH host key from
   `/nix/persist/etc/ssh/ssh_host_ed25519_key.pub`.
2. Adds the key to `private/nixos/secrets/lxc-management/secrets.nix`.
3. Re-encrypts the management secrets with the new key.

### 7. Commit and Deploy

New files must be committed for Nix flakes to see them:

```bash
git add .
git commit -m "feat: add new-lxc container"
rebuild -vL new-lxc
```

---

## Adding a New Darwin Machine

### 1. Bootstrap nix-darwin

On the new macOS machine, perform the one-time bootstrap:

```bash
mkdir -p ~/.config/nix-darwin
cd ~/.config/nix-darwin
nix flake init -t nix-darwin
sed -i '' "s/simple/$(scutil --get LocalHostName)/" flake.nix
# Edit flake.nix to enable nh: programs.nh.enable = true;
nix run nix-darwin -- switch --flake ~/.config/nix-darwin
```

### 2. Add to flake.nix

Add the machine to `darwinConfigurations` in `flake.nix`:

```nix
darwinConfigurations = {
  # ... existing hosts
  new-mac = mkDarwinHost {
    machine = "new-mac.hyades.io";
    role = "workstation";
    shared = false;
  };
};
```

### 3. Commit and Rebuild

```bash
git add .
git commit -m "feat: add new-mac workstation"
rebuild
```

---

## Secrets Management

Secrets are managed using `agenix` with `age` encryption. The identity key is
located at `~/.age/age.pem`, and encrypted secrets reside in the `private/`
submodule.

### Adding a New Secret

1. Create the secret file in the `private/` submodule.
2. Define recipients in `private/nixos/secrets/secrets.nix`.
3. Encrypt the file:
   ```bash
   agenix -e path/to/secret.age
   ```
4. Reference the secret in a Nix module:
   ```nix
   { private, ... }:
   {
     age.secrets."my-secret".file = "${private}/path/to/secret.age";
   }
   ```
5. **Commit in the `private/` submodule first**, then update the submodule
   reference in the main repository.

### Rotating a Secret

To re-encrypt a secret with the current list of recipients:

```bash
agenix -r path/to/secret.age
```

### Adding a Machine to Secret Recipients

1. Get the machine's SSH host key (usually `ssh-keyscan` or from
   `/etc/ssh/ssh_host_ed25519_key.pub`).
2. Add the key to `private/nixos/secrets/secrets.nix`.
3. Re-encrypt all secrets:
   ```bash
   cd private/nixos/secrets && agenix -r
   ```

---

## Proxmox Image Workflows

### Building Images

You can build Proxmox-compatible images directly from the flake:

```bash
rebuild --proxmox-lxc        # Build LXC tarball (.tar.xz)
rebuild --proxmox-vm-qcow2   # Build VM image (.qcow2)
```

### Deployment

1. Upload the generated image to Proxmox storage.
2. Create a new container or VM using the image.
3. For VMs, import the disk: `qm importdisk <vmid> <file> <storage>`.
4. Follow the
   [Adding a New Proxmox LXC Container](#adding-a-new-proxmox-lxc-container)
   procedure to manage it with Nix.

### Proxmox Host Configuration

For LXC containers running network services (cloudflared, tailscale), the
Proxmox host must be configured with specific sysctl settings:

```bash
ssh root@pve1 < scripts/pve-sysctl-setup.sh
```

This script configures:

- `net.core.rmem_max` / `net.core.wmem_max`: Increased UDP buffers for QUIC
  performance.
- `net.ipv4.ping_group_range`: Allows unprivileged ICMP (ping) for tunnel
  services.

---

## Binary Cache Management

The configuration uses a self-hosted binary cache at `ncps.hyades.io` (NCPS).

### How it Works

- **Post-build Hook**: Every build automatically triggers a `post-build-hook`
  defined in `shared/cache.nix` that copies the output to NCPS.
- **Signing Key**: The cache signing key is age-encrypted in `private/` and
  auto-decrypted by the `rebuild` tool into
  `~/.config/nix/config/private/cache-priv-key.pem`.
- **Substituter Chain**: Machines follow a substituter chain: `NCPS` -> `cachix`
  -> `cache.nixos.org`.

### Manual Cache Operations

To manually copy a path to the cache:

```bash
nix copy --to 'https://ncps.hyades.io' /nix/store/...
```

---

## File Synchronization (Mutagen)

File synchronization uses a hub-and-spoke topology with `aether` as the central
hub.

### Setup

On spoke machines (Darwin or other NixOS), run the setup function:

```bash
mutagen-setup
```

This creates bidirectional sync sessions for configured projects (Iniciador,
Hadenes, Personal, Hyades).

### Configuration

- **Hub**: `aether` (NixOS) serves as the central hub.
- **Spokes**: Darwin and other NixOS machines sync to the hub.
- **Ignore Patterns**: Defined in `home/common/sync/mutagen.nix` (e.g.,
  `node_modules`, `.git`, `target`, `__pycache__`).

---

## Troubleshooting Procedures

### Cache Timeout Errors

If you see `Connection timed out` when downloading from `ncps.hyades.io`:
**Retry the rebuild.** The build was interrupted, and the system may be in an
inconsistent state. This is often caused by transient network issues or the
cache server being busy.

### LXC Deployment Timeouts

LXC containers can be slow to build or have network issues during large
transfers. **Use `-vL` flags** to build locally and stream output:
`rebuild -vL <name>`. This prevents SSH timeouts by keeping the connection
active with build output.

### Tailscale Connectivity

The `rebuild` tool auto-detects Tailscale status. If disconnected, it skips
`100.x.x.x` addresses and falls back to LAN IPs. If you are remote, ensure
Tailscale is running:

```bash
tailscale status
```

### Stale home-manager Generations

If activation fails due to stale generations referencing missing secrets, clear
them:

```bash
home-manager generations | tail -n +2 | awk '{print $NF}' | xargs -I{} home-manager remove-generations {}
```

### Resilio Sync File Corruption

If git objects are corrupted by Resilio Sync temp files (`.rsls`):

```bash
# Delete corrupted git refs
git for-each-ref --format='%(refname)' | grep '\.rsls' | xargs -I {} git update-ref -d {}
# Delete temp files
find . -name "*.rsls*" -delete
# Prune remote
git remote prune origin
```

### Flake Not Seeing New Files

Nix flakes only see files tracked by git. **Always `git add` new files** before
running `rebuild` or `nix flake check`.

---

## Remote Machine Setup

To prepare a fresh machine for this configuration, use the `nix-remote-setup`
script:

```bash
nix-remote-setup <hostname>
```

This script automates:

1. **Age Identity**: Copies `~/.age/age.pem` to the remote.
2. **SSH Key**: Copies `~/.ssh/keys/id_ed25519` to the remote for private repo
   access.
3. **Nix Config**: Creates `~/.config/nix/nix.conf` with binary cache settings.
4. **Repo Clone**: Clones the repository with all submodules to
   `~/.config/nix/config/`.
5. **Cache Key**: Decrypts the cache signing key on the remote.

### Manual Activation after Setup

After `nix-remote-setup` completes, SSH into the machine and run:

**For Darwin (macOS):**

1. Bootstrap nix-darwin (see
   [Adding a New Darwin Machine](#adding-a-new-darwin-machine)).
2. Run `nh darwin switch --impure`.

**For NixOS:**

1. Run `sudo nixos-rebuild switch --flake ~/.config/nix/config/ --impure`.
