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
"""

import asyncio
import json
import os
import socket
import subprocess
import sys
from argparse import ArgumentParser
from dataclasses import dataclass
from typing import Optional

# Substituted by Nix at build time
NODE_CONFIG = json.loads('''@nodeConfigJson@''')
FLAKE_PATH = os.path.expanduser("~/.config/nix/config")
CACHE_KEY_PATH = "@cacheKeyPath@"
CACHE_KEY_AGE_PATH = "@cacheKeyAgePath@"
AGE_IDENTITY = "@ageIdentity@"
AGE_BIN = "@ageBin@"

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
    local: bool
    target_host: Optional[str] = None
    build_host: Optional[str] = None


def get_nodes() -> dict[str, Node]:
    """Parse node configuration into Node objects."""
    return {
        name: Node(
            name=name,
            type=cfg["type"],
            role=cfg["role"],
            tags=cfg["tags"],
            local=cfg["local"],
            target_host=cfg.get("targetHost"),
            build_host=cfg.get("buildHost"),
        )
        for name, cfg in NODE_CONFIG["nodes"].items()
    }


def get_current_host() -> str:
    """Get the current machine's hostname (short form, lowercase)."""
    hostname = socket.gethostname().split(".")[0].lower()
    # Handle common hostname suffixes
    for suffix in [".local", ".hyades.io"]:
        if hostname.endswith(suffix):
            hostname = hostname[:-len(suffix)]
    return hostname


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
            print(f"{YELLOW}[WARN]{NC} Age identity not found at {age_identity}, skipping cache key decryption")


def build_local_command(node: Node) -> list[str]:
    """Build the command for local deployment using nh."""
    nh_type = "darwin" if node.type == "darwin" else "os"
    return ["nh", nh_type, "switch", "--impure", "-H", node.name]


def build_remote_command(node: Node) -> list[str]:
    """Build the command for remote deployment using nixos-rebuild."""
    return [
        "nix", "shell", "nixpkgs#nixos-rebuild", "-c",
        "nixos-rebuild", "switch",
        "--fast",  # Skip rebuilding nixos-rebuild for target platform
        "--impure",
        "--flake", f"{FLAKE_PATH}#{node.name}",
        "--target-host", node.target_host,
        "--build-host", node.build_host,
        "--use-remote-sudo",
    ]


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
    print(f"{BLUE}[INFO]{NC} {log_prefix}Deploying to {BOLD}{node.name}{NC}...")

    if node.local:
        cmd = build_local_command(node)
    else:
        cmd = build_remote_command(node)

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    stdout, _ = await proc.communicate()
    output = stdout.decode()
    success = proc.returncode == 0

    # Print status
    if success:
        print(f"{GREEN}✓{NC} {log_prefix}{node.name} - deployment successful")
    else:
        print(f"{RED}✗{NC} {log_prefix}{node.name} - deployment failed")
        # Print last few lines of output on failure for context
        lines = output.strip().split("\n")
        if lines:
            print(f"{YELLOW}  Last output:{NC}")
            for line in lines[-5:]:
                print(f"    {line}")

    return node.name, success, output


async def deploy_parallel(nodes: list[Node]) -> bool:
    """
    Deploy to multiple nodes in parallel.

    Args:
        nodes: List of nodes to deploy to

    Returns:
        True if all deployments succeeded
    """
    node_names = ", ".join(n.name for n in nodes)
    print(f"{BLUE}[INFO]{NC} Parallel deployment to {len(nodes)} nodes: {BOLD}{node_names}{NC}")
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
                print(f"{YELLOW}[WARN]{NC} Deployment to {node.name} failed. Continue with remaining nodes? [y/N] ", end="")
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
            matching = [n for n in nodes.values() if tag in n.tags and n.name not in seen]
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


def list_nodes(nodes: dict[str, Node]) -> None:
    """Print all available nodes and tags."""
    print(f"{BOLD}Nodes:{NC}")
    for name in sorted(nodes.keys()):
        node = nodes[name]
        local_str = "local" if node.local else f"remote -> {node.target_host}"
        tags_str = " ".join(node.tags)
        print(f"  {BOLD}{name}{NC}: {node.type}/{node.role} ({local_str})")
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
        "-p", "--parallel",
        action="store_true",
        help="Deploy to multiple targets in parallel",
    )
    parser.add_argument(
        "-a", "--all",
        action="store_true",
        help="Deploy to all configured nodes",
    )
    parser.add_argument(
        "-n", "--dry-run",
        action="store_true",
        help="Show what would be deployed without executing",
    )
    parser.add_argument(
        "-l", "--list",
        action="store_true",
        help="List all nodes and tags",
    )
    args = parser.parse_args()

    nodes = get_nodes()

    # Handle --list
    if args.list:
        list_nodes(nodes)
        return

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
            print(f"{RED}[ERROR]{NC} Current host '{current}' not found in configuration")
            print(f"Available nodes: {', '.join(sorted(nodes.keys()))}")
            print(f"\nTip: Use 'rebuild --list' to see all nodes and tags")
            sys.exit(1)
        targets = [nodes[current]]

    if not targets:
        print(f"{RED}[ERROR]{NC} No deployment targets found")
        sys.exit(1)

    # Handle --dry-run
    if args.dry_run:
        print(f"{BOLD}Would deploy to:{NC}")
        for node in targets:
            method = "local" if node.local else f"remote ({node.target_host})"
            print(f"  {node.name} ({node.type}, {method})")
            if node.local:
                cmd = build_local_command(node)
            else:
                cmd = build_remote_command(node)
            print(f"    cmd: {' '.join(cmd)}")
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
