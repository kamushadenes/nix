#!/usr/bin/env python3
"""
Nix deployment tool with parallel execution and tag-based filtering.

Usage:
    rebuild              # Local rebuild (current machine)
    rebuild aether       # Deploy to single target
    rebuild @headless    # Deploy to all nodes with @headless tag
    rebuild @nixos       # Deploy to all NixOS machines
    rebuild @darwin      # Deploy to all Darwin machines
    rebuild -p @darwin   # Parallel deploy to all Darwin machines
    rebuild --all        # Deploy to all machines
    rebuild -pa          # Parallel deploy to all machines
    rebuild --list       # List nodes and tags
    rebuild -n @nixos    # Dry run - show what would deploy
    rebuild --proxmox    # Build Proxmox VM and LXC images
    rebuild --proxmox-vm # Build only Proxmox VM image
    rebuild --proxmox-lxc # Build only Proxmox LXC image
"""

import asyncio
import json
import os
import socket
import subprocess
import sys
from argparse import ArgumentParser
from dataclasses import dataclass

# Substituted by Nix at build time
NODE_CONFIG = json.loads('''@nodeConfigJson@''')
FLAKE_PATH = os.path.expanduser("~/.config/nix/config")
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


@dataclass
class Node:
    """Represents a deployment target node."""
    name: str
    type: str  # darwin | nixos
    role: str  # workstation | headless
    tags: list[str]
    target_hosts: list[str]  # List of hosts/IPs to try in order
    build_host: str


def get_nodes() -> dict[str, Node]:
    """Parse node configuration into Node objects."""
    return {
        name: Node(
            name=name,
            type=cfg["type"],
            role=cfg["role"],
            tags=cfg["tags"],
            target_hosts=cfg["targetHosts"],
            build_host=cfg["buildHost"],
        )
        for name, cfg in NODE_CONFIG["nodes"].items()
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
            print(f"{BLUE}[INFO]{NC} Decrypting cache signing key...")
            try:
                with open(cache_key_path, "w") as f:
                    subprocess.run(
                        [AGE_BIN, "-d", "-i", age_identity, cache_key_age_path],
                        stdout=f,
                        check=True,
                    )
                os.chmod(cache_key_path, 0o600)
            except subprocess.CalledProcessError as e:
                print(f"{YELLOW}[WARN]{NC} Failed to decrypt cache key: {e}")
        else:
            print(
                f"{YELLOW}[WARN]{NC} Age identity not found at {age_identity}, skipping cache key decryption"
            )


def check_remote_prepared(target_host: str) -> bool:
    """
    Check if a remote host has the required files for nix deployment.
    
    Checks for:
    - ~/.age/age.pem (age identity)
    - ~/.config/nix/config/ (nix config repo)
    
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
    
    Returns True if setup succeeded, False otherwise.
    """
    print(f"{BLUE}[INFO]{NC} Running nix-remote-setup for {target_host}...")
    try:
        result = subprocess.run(
            [NIX_REMOTE_SETUP, target_host],
            check=False,
        )
        if result.returncode == 0:
            print(f"{GREEN}✓{NC} Remote setup completed for {target_host}")
            return True
        else:
            print(f"{RED}✗{NC} Remote setup failed for {target_host}")
            return False
    except FileNotFoundError:
        print(f"{RED}[ERROR]{NC} nix-remote-setup not found at {NIX_REMOTE_SETUP}")
        return False
    except subprocess.SubprocessError as e:
        print(f"{RED}[ERROR]{NC} Failed to run nix-remote-setup: {e}")
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
        
        print(f"{YELLOW}[WARN]{NC} Remote {target_host} is not prepared for deployment")
        
        # Try to prepare it
        if prepare_remote(target_host):
            return True
    
    return False


def build_local_command(node: Node) -> list[str]:
    """Build the command for local deployment using nh."""
    nh_type = "darwin" if node.type == "darwin" else "os"
    return ["nh", nh_type, "switch", "--impure", "-H", node.name]


def build_remote_command(node: Node, target_host: str) -> list[str]:
    """Build the command for remote deployment using nixos-rebuild."""
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
        "--build-host",
        node.build_host,
        "--use-remote-sudo",
    ]


async def try_remote_hosts(node: Node, prefix: str = "") -> tuple[str, bool, str]:
    """
    Try deploying to each target host in order until one succeeds.

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
        print(
            f"{BLUE}[INFO]{NC} {log_prefix}Deploying to {BOLD}{node.name}{NC}{host_info}..."
        )

        cmd = build_remote_command(node, target_host)

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await proc.communicate()
        output = stdout.decode()
        success = proc.returncode == 0

        if success:
            print(f"{GREEN}✓{NC} {log_prefix}{node.name} - deployment successful")
            return node.name, True, output

        # If this wasn't the last host, try the next one
        if i < len(node.target_hosts) - 1:
            print(
                f"{YELLOW}[WARN]{NC} {log_prefix}Failed to deploy via {target_host}, trying next host..."
            )
        else:
            print(f"{RED}✗{NC} {log_prefix}{node.name} - deployment failed")
            lines = output.strip().split("\n")
            if lines:
                print(f"{YELLOW}  Last output:{NC}")
                for line in lines[-5:]:
                    print(f"    {line}")

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
            f"{BLUE}[INFO]{NC} {log_prefix}Deploying to {BOLD}{node.name}{NC} (local)..."
        )
        cmd = build_local_command(node)

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await proc.communicate()
        output = stdout.decode()
        success = proc.returncode == 0

        if success:
            print(f"{GREEN}✓{NC} {log_prefix}{node.name} - deployment successful")
        else:
            print(f"{RED}✗{NC} {log_prefix}{node.name} - deployment failed")
            lines = output.strip().split("\n")
            if lines:
                print(f"{YELLOW}  Last output:{NC}")
                for line in lines[-5:]:
                    print(f"    {line}")

        return node.name, success, output
    else:
        # Remote deployment - ensure remote is prepared first
        if not ensure_remote_prepared(node):
            print(f"{RED}✗{NC} {log_prefix}{node.name} - remote not prepared and setup failed")
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
        f"{BLUE}[INFO]{NC} Parallel deployment to {len(nodes)} nodes: {BOLD}{node_names}{NC}"
    )
    print()

    tasks = [deploy_node(node, prefix="parallel") for node in nodes]
    results = await asyncio.gather(*tasks)

    # Print summary
    print()
    print(f"{BLUE}[INFO]{NC} {BOLD}Deployment Summary:{NC}")
    all_success = True
    for name, success, _ in results:
        status = f"{GREEN}✓{NC}" if success else f"{RED}✗{NC}"
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
        print(f"\n{BLUE}[INFO]{NC} Deploying {i}/{len(nodes)}...")
        _, success, _ = asyncio.run(deploy_node(node))
        if not success:
            all_success = False
            # Ask whether to continue on failure
            if i < len(nodes):
                print(
                    f"{YELLOW}[WARN]{NC} Deployment to {node.name} failed. Continue with remaining nodes? [y/N] ",
                    end="",
                )
                try:
                    response = input().strip().lower()
                    if response not in ("y", "yes"):
                        print(f"{BLUE}[INFO]{NC} Stopping deployment.")
                        break
                except (EOFError, KeyboardInterrupt):
                    print(f"\n{BLUE}[INFO]{NC} Stopping deployment.")
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
                print(f"{YELLOW}[WARN]{NC} No nodes match tag: {tag}")
            for node in matching:
                result.append(node)
                seen.add(node.name)
        elif target in nodes:
            # Direct node name
            if target not in seen:
                result.append(nodes[target])
                seen.add(target)
        else:
            print(f"{RED}[ERROR]{NC} Unknown target: {target}")
            print(f"Available nodes: {', '.join(sorted(nodes.keys()))}")
            sys.exit(1)

    return result


def build_proxmox_images(vm: bool = True, lxc: bool = True) -> bool:
    """
    Build Proxmox VM and/or LXC images.

    Args:
        vm: Whether to build VM image
        lxc: Whether to build LXC image

    Returns:
        True if all builds succeeded
    """
    all_success = True
    targets = []
    if vm:
        targets.append("proxmox-vm")
    if lxc:
        targets.append("proxmox-lxc")

    for target in targets:
        print(f"{BLUE}[INFO]{NC} Building {BOLD}{target}{NC}...")
        cmd = ["nix", "build", f"{FLAKE_PATH}#{target}", "--impure", "-L"]

        result = subprocess.run(cmd)
        if result.returncode == 0:
            # Find the output file
            result_link = os.path.join(os.getcwd(), "result")
            if os.path.islink(result_link):
                real_path = os.path.realpath(result_link)
                print(f"{GREEN}✓{NC} {target} built successfully")
                print(f"  Output: {real_path}")
            else:
                print(f"{GREEN}✓{NC} {target} built successfully")
        else:
            print(f"{RED}✗{NC} {target} build failed")
            all_success = False

    return all_success


def list_nodes(nodes: dict[str, Node]) -> None:
    """Print all available nodes and tags."""
    current_host = get_current_host()
    print(f"{BOLD}Nodes:{NC} (current host: {current_host})")
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
        help="Build Proxmox VM and LXC images",
    )
    parser.add_argument(
        "--proxmox-vm",
        action="store_true",
        help="Build only Proxmox VM image (.vma.zst)",
    )
    parser.add_argument(
        "--proxmox-lxc",
        action="store_true",
        help="Build only Proxmox LXC image (.tar.xz)",
    )
    args = parser.parse_args()

    nodes = get_nodes()

    # Handle --list
    if args.list:
        list_nodes(nodes)
        return

    # Handle --proxmox, --proxmox-vm, --proxmox-lxc
    if args.proxmox or args.proxmox_vm or args.proxmox_lxc:
        build_vm = args.proxmox or args.proxmox_vm
        build_lxc = args.proxmox or args.proxmox_lxc
        success = build_proxmox_images(vm=build_vm, lxc=build_lxc)
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
                f"{RED}[ERROR]{NC} Current host '{current}' not found in configuration"
            )
            print(f"Available nodes: {', '.join(sorted(nodes.keys()))}")
            print(f"\nTip: Use 'rebuild --list' to see all nodes and tags")
            sys.exit(1)
        targets = [nodes[current]]

    if not targets:
        print(f"{RED}[ERROR]{NC} No deployment targets found")
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
