#!/usr/bin/env python3
"""
ClickUp Sync - Deterministic bidirectional sync between beads and ClickUp.

Usage:
    clickup-sync           # Run sync
    clickup-sync --dry-run # Show what would be done
    clickup-sync --status  # Show sync status
"""

import argparse
import sys
from pathlib import Path

# Support running as both a module and a standalone script
try:
    from . import (
        BeadsClient,
        ClickUpMCPClient,
        ConfigError,
        KeychainError,
        SyncEngine,
        get_clickup_token,
        load_config,
        save_config,
    )
except ImportError:
    # Running as standalone script
    from beads_client import BeadsClient
    from mcp_client import ClickUpMCPClient
    from config import ConfigError, load_config, save_config
    from keychain import KeychainError, get_clickup_token
    from sync_engine import SyncEngine


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Sync beads with ClickUp bidirectionally",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  clickup-sync              # Run full sync
  clickup-sync --status     # Check configuration
  clickup-sync --dry-run    # Preview changes (not implemented yet)
  clickup-sync -v           # Verbose output
        """,
    )
    parser.add_argument(
        "--dry-run",
        "-n",
        action="store_true",
        help="Show what would be done without making changes",
    )
    parser.add_argument(
        "--status",
        "-s",
        action="store_true",
        help="Show sync configuration and status",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Verbose output",
    )

    args = parser.parse_args()

    # Check for .beads directory
    beads_dir = Path(".beads")
    if not beads_dir.exists():
        print(
            "Error: Not a beads repository. Run 'bd init' first.",
            file=sys.stderr,
        )
        return 1

    # Load configuration
    try:
        config = load_config(beads_dir)
    except ConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # Status mode
    if args.status:
        print(f"ClickUp List: {config.list_name} ({config.list_id})")
        print(f"Space: {config.space_name or config.space_id}")
        print(f"Last sync: {config.last_sync or 'Never'}")
        return 0

    # Get OAuth token from keychain
    try:
        token = get_clickup_token()
    except KeychainError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # Dry run mode (placeholder)
    if args.dry_run:
        print("Dry run mode - not fully implemented yet")
        print("Would sync with ClickUp list:", config.list_name)
        return 0

    # Initialize clients
    api = ClickUpMCPClient(token)
    beads = BeadsClient(cwd=".")
    engine = SyncEngine(api, beads, config, verbose=args.verbose)

    # Run sync
    print(f"Syncing with ClickUp list: {config.list_name}...")

    try:
        result = engine.sync()
    except Exception as e:
        print(f"Sync failed: {e}", file=sys.stderr)
        return 1

    # Update last_sync timestamp
    save_config(config, beads_dir)

    # Report results
    print()
    print("Sync complete:")
    print(f"  {result}")

    if result.errors:
        print(f"\nErrors ({len(result.errors)}):")
        for error in result.errors:
            print(f"  - {error}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
