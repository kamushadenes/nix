#!/usr/bin/env python3
"""
Nix deployment tool with parallel execution and tag-based filtering.

Usage:
    rebuild              # Local rebuild (current machine)
    rebuild aether       # Deploy to single target
    rebuild -vL cloudflared  # LXC deploy: verbose + local build (recommended)
    rebuild @headless    # Deploy to all nodes with @headless tag
    rebuild @nixos       # Deploy to all NixOS machines
    rebuild @darwin      # Deploy to all Darwin machines
    rebuild -p @darwin   # Parallel deploy to all Darwin machines
    rebuild --all        # Deploy to all machines
    rebuild -pa          # Parallel deploy to all machines
    rebuild --list       # List nodes and tags
    rebuild -n @nixos    # Dry run - show what would deploy
    rebuild --proxmox    # Build Proxmox VM (qcow2) and LXC images
    rebuild --proxmox-vm # Build Proxmox VM image (.vma.zst, currently broken)
    rebuild --proxmox-vm-qcow2 # Build Proxmox VM image (.qcow2, use qm importdisk)
    rebuild --proxmox-lxc # Build only Proxmox LXC image
"""

import asyncio
import ipaddress
import json
import os
import shutil
import socket
import subprocess
import sys
from argparse import ArgumentParser
from dataclasses import dataclass
from functools import lru_cache

# Paths
FLAKE_PATH = os.path.expanduser("~/.config/nix/config")
NODES_JSON_PATH = os.path.join(FLAKE_PATH, "private", "nodes.json")
CACHE_KEY_PATH = "@cacheKeyPath@"
CACHE_KEY_AGE_PATH = "@cacheKeyAgePath@"
AGE_IDENTITY = "@ageIdentity@"
AGE_BIN = "@ageBin@"
NIX_REMOTE_SETUP = "@nixRemoteSetup@"

# ANSI colors for terminal output
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
BOLD = "\033[1m"
NC = "\033[0m"  # No Color / Reset

# Tailscale CGNAT range: 100.64.0.0/10 (100.64.0.0 - 100.127.255.255)
TAILSCALE_CGNAT = ipaddress.ip_network("100.64.0.0/10")


def find_tailscale_binary() -> str | None:
    """Find the tailscale binary on the system.

    Checks common locations:
    - PATH (Linux/NixOS)
    - /Applications/Tailscale.app/Contents/MacOS/Tailscale (macOS App Store)
    """
    # Try PATH first (works on NixOS and if tailscale is in PATH)
    tailscale = shutil.which("tailscale")
    if tailscale:
        return tailscale

    # macOS App Store location
    macos_app = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    if os.path.exists(macos_app):
        return macos_app

    return None


@lru_cache(maxsize=1)
def is_tailscale_connected() -> bool:
    """Check if Tailscale is connected.

    Uses `tailscale status --json` to check if BackendState is "Running".
    Returns False if tailscale is not installed or not running.
    """
    tailscale = find_tailscale_binary()
    if not tailscale:
        return False

    try:
        result = subprocess.run(
            [tailscale, "status", "--json"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return False

        status = json.loads(result.stdout)
        return status.get("BackendState") == "Running"
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, json.JSONDecodeError):
        return False


def is_tailscale_ip(host: str) -> bool:
    """Check if a host is a Tailscale IP address (100.64.0.0/10 CGNAT range).

    Args:
        host: Hostname or IP address to check (may include user@ prefix)

    Returns:
        True if the host is an IP in the Tailscale CGNAT range
    """
    # Strip user@ prefix if present
    if "@" in host:
        host = host.split("@", 1)[1]

    try:
        ip = ipaddress.ip_address(host)
        return ip in TAILSCALE_CGNAT
    except ValueError:
        # Not a valid IP address (hostname), not a Tailscale IP
        return False


def filter_tailscale_ips(hosts: list[str], tailscale_up: bool) -> list[str]:
    """Filter out Tailscale IPs from host list if Tailscale is not connected.

    Args:
        hosts: List of hostnames/IPs to filter
        tailscale_up: Whether Tailscale is connected

    Returns:
        Filtered list of hosts (Tailscale IPs removed if Tailscale is down)
    """
    if tailscale_up:
        return hosts

    filtered = [h for h in hosts if not is_tailscale_ip(h)]
    return filtered


@dataclass
class Node:
    """Represents a deployment target node."""
    name: str
    type: str  # darwin | nixos
    role: str  # workstation | headless
    tags: list[str]
    target_hosts: list[str]  # List of hosts/IPs to try in order
    build_host: str
    ssh_port: int  # SSH port (default: 22)
    user: str | None = None  # SSH user override (prepended to target_hosts)


def load_node_config() -> dict:
    """Load node configuration from nodes.json file.

    Reads from FLAKE_PATH/shared/nodes.json and processes each node
    to add computed fields (tags, buildHost defaults).

    Returns:
        Dictionary with 'nodes' key containing processed node configs
    """
    with open(NODES_JSON_PATH) as f:
        raw_config = json.load(f)

    # Process each node to add computed fields
    nodes = {}
    for name, cfg in raw_config["nodes"].items():
        user = cfg.get("user")  # SSH user override (e.g., "root")
        target_hosts = cfg.get("targetHosts", [name])

        # Prepend user@ to each target host if user is specified
        if user:
            target_hosts = [f"{user}@{h}" for h in target_hosts]

        nodes[name] = {
            "type": cfg["type"],
            "role": cfg["role"],
            "tags": [f"@{cfg['type']}", f"@{cfg['role']}"],
            "targetHosts": target_hosts,
            "buildHost": cfg.get("buildHost", name),
            "sshPort": cfg.get("sshPort", 22),
            "user": user,
        }

    return {"nodes": nodes}


def get_nodes(tailscale_up: bool = True) -> dict[str, Node]:
    """Parse node configuration into Node objects.

    Args:
        tailscale_up: Whether Tailscale is connected. If False, Tailscale IPs
                      are filtered from target_hosts.

    Returns:
        Dictionary of node name to Node object
    """
    node_config = load_node_config()
    return {
        name: Node(
            name=name,
            type=cfg["type"],
            role=cfg["role"],
            tags=cfg["tags"],
            target_hosts=filter_tailscale_ips(cfg["targetHosts"], tailscale_up),
            build_host=cfg["buildHost"],
            ssh_port=cfg.get("sshPort", 22),
            user=cfg.get("user"),
        )
        for name, cfg in node_config["nodes"].items()
    }


def get_current_host() -> str:
    """Get the current machine's hostname (short form, lowercase).

    On macOS, uses scutil --get ComputerName which returns the nix-darwin
    configured name, as socket.gethostname() may return a different value
    (the DNS hostname rather than the machine name).
    """
    # Try macOS-specific method first (scutil --get ComputerName)
    try:
        result = subprocess.run(
            ["scutil", "--get", "ComputerName"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip().lower()
    except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.SubprocessError):
        pass

    # Fall back to socket.gethostname() for NixOS and other systems
    hostname = socket.gethostname().split(".")[0].lower()
    # Handle common hostname suffixes
    for suffix in [".local", ".hyades.io"]:
        if hostname.endswith(suffix):
            hostname = hostname[: -len(suffix)]
    return hostname


def is_local_deploy(node: Node) -> bool:
    """Check if deployment target is the current machine."""
    current = get_current_host()
    return current == node.name


def decrypt_cache_key() -> None:
    """Decrypt the cache signing key if it exists and hasn't been decrypted."""
    cache_key_path = os.path.expanduser(CACHE_KEY_PATH)
    cache_key_age_path = os.path.expanduser(CACHE_KEY_AGE_PATH)
    age_identity = os.path.expanduser(AGE_IDENTITY)

    if os.path.exists(cache_key_age_path) and not os.path.exists(cache_key_path):
        if os.path.exists(age_identity):
            print(f"{BLUE}[ * ]{NC} Decrypting cache signing key...")
            try:
                with open(cache_key_path, "w") as f:
                    subprocess.run(
                        [AGE_BIN, "-d", "-i", age_identity, cache_key_age_path],
                        stdout=f,
                        check=True,
                    )
                os.chmod(cache_key_path, 0o600)
            except subprocess.CalledProcessError as e:
                print(f"{YELLOW}[ ! ]{NC} Failed to decrypt cache key: {e}")
        else:
            print(
                f"{YELLOW}[ ! ]{NC} Age identity not found at {age_identity}, skipping cache key decryption"
            )


def check_remote_prepared(target_host: str) -> bool:
    """
    Check if a remote host has the required files for nix deployment.

    Checks for:
    - ~/.age/age.pem (age identity)
    - ~/.config/nix/config/ (nix config repo)

    Uses SSH config for connection settings (port, identity, etc.)

    Returns True if remote is prepared, False otherwise.
    """
    try:
        result = subprocess.run(
            [
                "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
                target_host,
                "test -f ~/.age/age.pem && test -d ~/.config/nix/config/"
            ],
            capture_output=True,
            timeout=15,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
        return False


def prepare_remote(target_host: str) -> bool:
    """
    Run nix-remote-setup to prepare a remote host for deployment.

    Uses SSH config for connection settings.

    Returns True if setup succeeded, False otherwise.
    """
    print(f"{BLUE}[ * ]{NC} Running nix-remote-setup for {target_host}...")
    try:
        result = subprocess.run(
            [NIX_REMOTE_SETUP, target_host],
            check=False,
        )
        if result.returncode == 0:
            print(f"{GREEN}[ ✓ ]{NC} Remote setup completed for {target_host}")
            return True
        else:
            print(f"{RED}[ ✗ ]{NC} Remote setup failed for {target_host}")
            return False
    except FileNotFoundError:
        print(f"{RED}[ ✗ ]{NC} nix-remote-setup not found at {NIX_REMOTE_SETUP}")
        return False
    except subprocess.SubprocessError as e:
        print(f"{RED}[ ✗ ]{NC} Failed to run nix-remote-setup: {e}")
        return False


def ensure_remote_prepared(node: Node) -> bool:
    """
    Ensure a remote node is prepared for deployment.

    Checks each target host and runs nix-remote-setup if needed.
    Returns True if at least one host is prepared/preparable.
    """
    for target_host in node.target_hosts:
        if check_remote_prepared(target_host):
            return True

        print(f"{YELLOW}[ ! ]{NC} Remote {target_host} is not prepared for deployment")

        # Try to prepare it
        if prepare_remote(target_host):
            return True

    return False


def build_local_command(node: Node) -> list[str]:
    """Build the command for local deployment using nh."""
    nh_type = "darwin" if node.type == "darwin" else "os"
    # Pass FLAKE_PATH explicitly to ensure it works when nh uses sudo internally
    return ["nh", nh_type, "switch", "--impure", "-H", node.name, FLAKE_PATH]


def build_remote_command(node: Node, target_host: str) -> list[str]:
    """Build the command for remote deployment using nixos-rebuild.

    Builds locally (no --build-host) and pushes to target_host.
    This is faster for LXCs with limited resources.
    """
    return [
        "nix",
        "shell",
        "nixpkgs#nixos-rebuild",
        "-c",
        "nixos-rebuild",
        "switch",
        "--fast",  # Skip rebuilding nixos-rebuild for target platform
        "--impure",
        "--flake",
        f"{FLAKE_PATH}#{node.name}",
        "--target-host",
        target_host,
        "--use-remote-sudo",
    ]


# Global flags
VERBOSE = False
LOCAL_BUILD = False


def get_nix_ssh_env(ssh_port: int) -> dict[str, str]:
    """Get environment with NIX_SSHOPTS for custom SSH port and host key checking."""
    env = os.environ.copy()
    ssh_opts = ["-o", "StrictHostKeyChecking=accept-new"]
    if ssh_port != 22:
        ssh_opts.extend(["-p", str(ssh_port)])
    env["NIX_SSHOPTS"] = " ".join(ssh_opts)
    return env




def is_connection_error(output: str) -> bool:
    """
    Check if the error output indicates a connection failure vs deployment failure.

    Connection failures should trigger fallback to the next host.
    Deployment failures (build errors, etc.) should not.
    """
    connection_error_patterns = [
        "Connection refused",
        "Connection timed out",
        "Operation timed out",
        "No route to host",
        "Network is unreachable",
        "Name or service not known",
        "Could not resolve hostname",
        "Host is down",
        "Permission denied (publickey",
        "ssh: connect to host",
        "ssh_exchange_identification",
    ]
    output_lower = output.lower()
    return any(pattern.lower() in output_lower for pattern in connection_error_patterns)


async def check_ssh_connection(target_host: str) -> tuple[bool, str]:
    """
    Quick SSH connection check to verify host is reachable.

    Uses SSH config for connection settings (port, identity, etc.)

    Returns (success, error_message).
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new",
            target_host, "true",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await proc.communicate()
        output = stdout.decode()
        return proc.returncode == 0, output
    except Exception as e:
        return False, str(e)


async def try_remote_hosts(node: Node, prefix: str = "") -> tuple[str, bool, str]:
    """
    Try deploying to each target host in order until one succeeds.

    Only falls back to the next host on connection errors.
    Deployment failures (build errors, etc.) are returned immediately.

    Args:
        node: The node to deploy to
        prefix: Optional prefix for log messages

    Returns:
        Tuple of (node_name, success, output)
    """
    log_prefix = f"[{node.name}] " if prefix else ""
    output = ""

    for i, target_host in enumerate(node.target_hosts):
        host_info = (
            f" (host {i + 1}/{len(node.target_hosts)}: {target_host})"
            if len(node.target_hosts) > 1
            else ""
        )

        # First, check if we can connect to this host
        print(
            f"{BLUE}[ * ]{NC} {log_prefix}Checking connectivity to {target_host}..."
        )
        conn_ok, conn_output = await check_ssh_connection(target_host)

        if not conn_ok:
            # Connection failed - try next host if available
            if i < len(node.target_hosts) - 1:
                print(
                    f"{YELLOW}[ ! ]{NC} {log_prefix}Cannot connect to {target_host}, trying next host..."
                )
                continue
            else:
                print(f"{RED}[ ✗ ]{NC} {log_prefix}{node.name} - all hosts unreachable")
                return node.name, False, conn_output

        # Connection succeeded - proceed with deployment using the working host
        print(
            f"{BLUE}[ * ]{NC} {log_prefix}Deploying to {BOLD}{node.name}{NC}{host_info}..."
        )

        cmd = build_remote_command(node, target_host)
        env = get_nix_ssh_env(node.ssh_port)

        if VERBOSE:
            # Stream output in real-time
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=None,  # Inherit stdout
                stderr=None,  # Inherit stderr
                env=env,
            )
            await proc.wait()
            output = ""
            success = proc.returncode == 0
        else:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                env=env,
            )
            stdout, _ = await proc.communicate()
            output = stdout.decode()
            success = proc.returncode == 0

        if success:
            print(f"{GREEN}[ ✓ ]{NC} {log_prefix}{node.name} - deployment successful")
            return node.name, True, output

        # Deployment failed - check if it's a connection error or actual deployment failure
        if is_connection_error(output) and i < len(node.target_hosts) - 1:
            # Show the actual error before trying next host
            lines = output.strip().split("\n")
            print(
                f"{YELLOW}[ ! ]{NC} {log_prefix}Connection error to {target_host}:"
            )
            for line in lines[-5:]:
                print(f"    {line}")
            print(f"{YELLOW}[ * ]{NC} Trying next host...")
            continue

        # Deployment failure (not connection-related) - return error immediately
        print(f"{RED}[ ✗ ]{NC} {log_prefix}{node.name} - deployment failed")
        lines = output.strip().split("\n")
        if lines:
            print(f"{YELLOW}[ * ]{NC} Last output:")
            for line in lines[-10:]:
                print(f"    {line}")
        return node.name, False, output

    return node.name, False, output


async def deploy_node(node: Node, prefix: str = "") -> tuple[str, bool, str]:
    """
    Deploy to a single node asynchronously.

    Args:
        node: The node to deploy to
        prefix: Optional prefix for log messages (used in parallel mode)

    Returns:
        Tuple of (node_name, success, output)
    """
    log_prefix = f"[{node.name}] " if prefix else ""

    # Determine if this is a local or remote deployment
    if is_local_deploy(node):
        print(
            f"{BLUE}[ * ]{NC} {log_prefix}Deploying to {BOLD}{node.name}{NC} (local)..."
        )
        cmd = build_local_command(node)

        if VERBOSE:
            # Stream output in real-time
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=None,  # Inherit stdout
                stderr=None,  # Inherit stderr
            )
            await proc.wait()
            output = ""
            success = proc.returncode == 0
        else:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
            stdout, _ = await proc.communicate()
            output = stdout.decode()
            success = proc.returncode == 0

        if success:
            print(f"{GREEN}[ ✓ ]{NC} {log_prefix}{node.name} - deployment successful")
        else:
            print(f"{RED}[ ✗ ]{NC} {log_prefix}{node.name} - deployment failed")
            if not VERBOSE:
                lines = output.strip().split("\n")
                if lines:
                    print(f"{YELLOW}[ * ]{NC} Last output:")
                    for line in lines[-5:]:
                        print(f"    {line}")

        return node.name, success, output
    else:
        # Remote deployment
        # When using local build, skip remote preparation (no need to copy age/ssh keys)
        if not LOCAL_BUILD:
            # Ensure remote is prepared first
            if not ensure_remote_prepared(node):
                print(f"{RED}[ ✗ ]{NC} {log_prefix}{node.name} - remote not prepared and setup failed")
                return node.name, False, "Remote not prepared for deployment"

        # Remote deployment - try each host in order
        return await try_remote_hosts(node, prefix)


async def deploy_parallel(nodes: list[Node]) -> bool:
    """
    Deploy to multiple nodes in parallel.

    Args:
        nodes: List of nodes to deploy to

    Returns:
        True if all deployments succeeded
    """
    node_names = ", ".join(n.name for n in nodes)
    print(
        f"{BLUE}[ * ]{NC} Parallel deployment to {len(nodes)} nodes: {BOLD}{node_names}{NC}"
    )
    print()

    tasks = [deploy_node(node, prefix="parallel") for node in nodes]
    results = await asyncio.gather(*tasks)

    # Print summary
    print()
    print(f"{BLUE}[ * ]{NC} {BOLD}Deployment Summary:{NC}")
    all_success = True
    for name, success, _ in results:
        status = f"{GREEN}[ ✓ ]{NC}" if success else f"{RED}[ ✗ ]{NC}"
        print(f"  {status} {name}")
        if not success:
            all_success = False

    return all_success


def deploy_sequential(nodes: list[Node]) -> bool:
    """
    Deploy to multiple nodes sequentially.

    Args:
        nodes: List of nodes to deploy to

    Returns:
        True if all deployments succeeded
    """
    all_success = True
    for i, node in enumerate(nodes, 1):
        print(f"\n{BLUE}[ * ]{NC} Deploying {i}/{len(nodes)}...")
        _, success, _ = asyncio.run(deploy_node(node))
        if not success:
            all_success = False
            # Ask whether to continue on failure
            if i < len(nodes):
                print(
                    f"{YELLOW}[ ! ]{NC} Deployment to {node.name} failed. Continue with remaining nodes? [y/N] ",
                    end="",
                )
                try:
                    response = input().strip().lower()
                    if response not in ("y", "yes"):
                        print(f"{BLUE}[ * ]{NC} Stopping deployment.")
                        break
                except (EOFError, KeyboardInterrupt):
                    print(f"\n{BLUE}[ * ]{NC} Stopping deployment.")
                    break
    return all_success


def expand_targets(targets: list[str], nodes: dict[str, Node]) -> list[Node]:
    """
    Expand tags and node names to a list of Node objects.

    Args:
        targets: List of node names or @tags
        nodes: Dict of all available nodes

    Returns:
        List of matching Node objects
    """
    result = []
    seen = set()

    for target in targets:
        if target.startswith("@"):
            # Tag - find all matching nodes
            tag = target
            matching = [
                n for n in nodes.values() if tag in n.tags and n.name not in seen
            ]
            if not matching:
                print(f"{YELLOW}[ ! ]{NC} No nodes match tag: {tag}")
            for node in matching:
                result.append(node)
                seen.add(node.name)
        elif target in nodes:
            # Direct node name
            if target not in seen:
                result.append(nodes[target])
                seen.add(target)
        else:
            print(f"{RED}[ ✗ ]{NC} Unknown target: {target}")
            print(f"Available nodes: {', '.join(sorted(nodes.keys()))}")
            sys.exit(1)

    return result


def build_proxmox_images(vm: bool = False, vm_qcow2: bool = False, lxc: bool = False) -> bool:
    """
    Build Proxmox VM and/or LXC images.

    Args:
        vm: Whether to build VM image (VMA format, currently broken)
        vm_qcow2: Whether to build VM image (qcow2 format, working)
        lxc: Whether to build LXC image

    Returns:
        True if all builds succeeded
    """
    from datetime import datetime
    import glob as glob_module

    all_success = True
    targets = []
    if vm:
        # NOTE: proxmox-vm (VMA format) is broken due to a qemu vma bug:
        # "vma_writer_close failed vma_queue_write: write error - Invalid argument"
        print(f"{YELLOW}[ ! ]{NC} VMA format is currently broken (qemu vma bug)")
        print(f"{YELLOW}[ ! ]{NC} Consider using --proxmox-vm-qcow2 instead")
        targets.append("proxmox-vm")
    if vm_qcow2:
        # qcow2 format as workaround. Import with: qm importdisk <vmid> <file> <storage>
        targets.append("proxmox-vm-qcow2")
    if lxc:
        targets.append("proxmox-lxc")

    # Expected output extensions for each target type
    extensions = {
        "proxmox-vm": ".vma.zst",
        "proxmox-vm-qcow2": ".qcow2",
        "proxmox-lxc": ".tar.xz",
    }

    for target in targets:
        print(f"{BLUE}[ * ]{NC} Building {BOLD}{target}{NC}...")
        # Proxmox images are x86_64-linux only, explicitly specify to use remote builder
        cmd = ["nix", "build", f"{FLAKE_PATH}#packages.x86_64-linux.{target}", "--impure", "-L"]

        result = subprocess.run(cmd)
        if result.returncode == 0:
            # Find the output file
            result_link = os.path.join(os.getcwd(), "result")
            if os.path.islink(result_link):
                real_path = os.path.realpath(result_link)

                # Find the actual image file in the output directory (may be nested)
                ext = extensions.get(target, ".*")
                pattern = os.path.join(real_path, "**", f"*{ext}")
                matches = glob_module.glob(pattern, recursive=True)

                if matches:
                    src_file = matches[0]
                    # Create a meaningful filename with timestamp
                    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
                    dest_name = f"nixos-{target}-{timestamp}{ext}"
                    dest_path = os.path.join(os.getcwd(), dest_name)

                    # Copy the file to cwd
                    print(f"{BLUE}[ * ]{NC} Copying to {dest_name}...")
                    shutil.copy2(src_file, dest_path)

                    # Clean up the result symlink
                    os.unlink(result_link)

                    print(f"{GREEN}[ ✓ ]{NC} {target} built successfully")
                    print(f"  Output: {dest_path}")
                else:
                    print(f"{GREEN}[ ✓ ]{NC} {target} built successfully")
                    print(f"  Output: {real_path}")

                    # Clean up the result symlink
                    os.unlink(result_link)
            else:
                print(f"{GREEN}[ ✓ ]{NC} {target} built successfully")
        else:
            print(f"{RED}[ ✗ ]{NC} {target} build failed")
            all_success = False

    return all_success


def list_nodes(nodes: dict[str, Node], tailscale_up: bool = True) -> None:
    """Print all available nodes and tags."""
    current_host = get_current_host()
    ts_status = f"{GREEN}connected{NC}" if tailscale_up else f"{YELLOW}disconnected{NC}"
    print(f"{BOLD}Nodes:{NC} (current host: {current_host}, tailscale: {ts_status})")
    for name in sorted(nodes.keys()):
        node = nodes[name]
        is_local = name == current_host
        if is_local:
            deploy_method = "local"
        else:
            hosts_str = ", ".join(node.target_hosts)
            deploy_method = f"remote -> [{hosts_str}]"
        tags_str = " ".join(node.tags)
        print(f"  {BOLD}{name}{NC}: {node.type}/{node.role} ({deploy_method})")
        print(f"    tags: {tags_str}")

    # Collect and display all unique tags
    all_tags = sorted(set(tag for n in nodes.values() for tag in n.tags))
    print(f"\n{BOLD}Tags:{NC}")
    for tag in all_tags:
        matching = sorted(n.name for n in nodes.values() if tag in n.tags)
        print(f"  {tag}: {', '.join(matching)}")


def main() -> None:
    parser = ArgumentParser(
        description="Nix deployment tool with parallel execution and tag-based filtering",
        epilog="Examples:\n"
        "  rebuild              Local rebuild (current machine)\n"
        "  rebuild aether       Deploy to aether\n"
        "  rebuild @nixos       Deploy to all NixOS machines\n"
        "  rebuild -p @darwin   Parallel deploy to all Darwin machines\n"
        "  rebuild --all        Deploy to all machines\n",
    )
    parser.add_argument(
        "targets",
        nargs="*",
        help="Nodes or @tags to deploy (default: current host)",
    )
    parser.add_argument(
        "-p",
        "--parallel",
        action="store_true",
        help="Deploy to multiple targets in parallel",
    )
    parser.add_argument(
        "-a",
        "--all",
        action="store_true",
        help="Deploy to all configured nodes",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Show what would be deployed without executing",
    )
    parser.add_argument(
        "-l",
        "--list",
        action="store_true",
        help="List all nodes and tags",
    )
    parser.add_argument(
        "--proxmox",
        action="store_true",
        help="Build Proxmox VM (qcow2) and LXC images",
    )
    parser.add_argument(
        "--proxmox-vm",
        action="store_true",
        help="Build Proxmox VM image (.vma.zst, currently broken)",
    )
    parser.add_argument(
        "--proxmox-vm-qcow2",
        action="store_true",
        help="Build Proxmox VM image (.qcow2, import with qm importdisk)",
    )
    parser.add_argument(
        "--proxmox-lxc",
        action="store_true",
        help="Build only Proxmox LXC image (.tar.xz)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Stream deployment output in real-time (recommended for LXC/slow builds)",
    )
    parser.add_argument(
        "-L",
        "--local-build",
        action="store_true",
        help="Build locally and push to remote (recommended for LXCs with limited resources)",
    )
    args = parser.parse_args()

    # Set global flags
    global VERBOSE, LOCAL_BUILD
    VERBOSE = args.verbose
    LOCAL_BUILD = args.local_build

    # Check Tailscale connection status
    tailscale_up = is_tailscale_connected()
    if not tailscale_up:
        print(f"{YELLOW}[ ! ]{NC} Tailscale not connected - skipping 100.x.x.x addresses")

    nodes = get_nodes(tailscale_up)

    # Handle --list
    if args.list:
        list_nodes(nodes, tailscale_up)
        return

    # Handle --proxmox, --proxmox-vm, --proxmox-vm-qcow2, --proxmox-lxc
    if args.proxmox or args.proxmox_vm or args.proxmox_vm_qcow2 or args.proxmox_lxc:
        build_vm = args.proxmox_vm
        build_vm_qcow2 = args.proxmox or args.proxmox_vm_qcow2  # --proxmox uses qcow2
        build_lxc = args.proxmox or args.proxmox_lxc
        success = build_proxmox_images(vm=build_vm, vm_qcow2=build_vm_qcow2, lxc=build_lxc)
        sys.exit(0 if success else 1)

    # Decrypt cache key before deployment
    decrypt_cache_key()

    # Determine deployment targets
    if args.all:
        targets = list(nodes.values())
    elif args.targets:
        targets = expand_targets(args.targets, nodes)
    else:
        # Default: deploy to current host
        current = get_current_host()
        if current not in nodes:
            print(
                f"{RED}[ ✗ ]{NC} Current host '{current}' not found in configuration"
            )
            print(f"Available nodes: {', '.join(sorted(nodes.keys()))}")
            print(f"\nTip: Use 'rebuild --list' to see all nodes and tags")
            sys.exit(1)
        targets = [nodes[current]]

    if not targets:
        print(f"{RED}[ ✗ ]{NC} No deployment targets found")
        sys.exit(1)

    # Handle --dry-run
    if args.dry_run:
        current_host = get_current_host()
        print(f"{BOLD}Would deploy to:{NC} (current host: {current_host})")
        for node in targets:
            is_local = node.name == current_host
            if is_local:
                method = "local"
                cmd = build_local_command(node)
                print(f"  {node.name} ({node.type}, {method})")
                print(f"    cmd: {' '.join(cmd)}")
            else:
                hosts_str = " -> ".join(node.target_hosts)
                method = f"remote ({hosts_str})"
                print(f"  {node.name} ({node.type}, {method})")
                for i, host in enumerate(node.target_hosts):
                    cmd = build_remote_command(node, host)
                    prefix = "    cmd" if len(node.target_hosts) == 1 else f"    [{i+1}]"
                    print(f"{prefix}: {' '.join(cmd)}")
        return

    # Execute deployment
    if len(targets) == 1:
        _, success, _ = asyncio.run(deploy_node(targets[0]))
    elif args.parallel:
        success = asyncio.run(deploy_parallel(targets))
    else:
        success = deploy_sequential(targets)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
