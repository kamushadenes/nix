#!/usr/bin/env python3
"""
ClickUp Sync - Deterministic bidirectional sync between beads and ClickUp.

Usage:
    clickup-sync                    # Run sync (uses account from config)
    clickup-sync --status           # Show sync status
    clickup-sync list               # List ClickUp tasks
    clickup-sync delete <task_id>   # Delete/archive tasks
"""

import argparse
import sys
from pathlib import Path

# Support running as both a module and a standalone script
try:
    from . import (
        BeadsClient,
        ClickUpAPI,
        ClickUpAPIError,
        ConfigError,
        SyncEngine,
        load_config,
        save_config,
    )
except ImportError:
    # Running as standalone script
    from beads_client import BeadsClient
    from clickup_api import ClickUpAPI, ClickUpAPIError
    from config import ConfigError, load_config, save_config
    from sync_engine import SyncEngine


class TokenError(Exception):
    """Error loading API token."""


def get_token(account: str) -> str:
    """
    Load ClickUp API token from secrets file.

    Args:
        account: Account name (e.g., "iniciador")

    Returns:
        API token string

    Raises:
        TokenError: If token file not found or empty
    """
    token_path = Path.home() / ".claude" / "secrets" / f"{account}-clickup-token"
    if not token_path.exists():
        raise TokenError(
            f"Token file not found: {token_path}\n"
            f"Ensure agenix secret is configured for account '{account}'."
        )
    token = token_path.read_text().strip()
    if not token:
        raise TokenError(f"Token file is empty: {token_path}")
    return token


def cmd_list(api: ClickUpAPI, config, args) -> int:
    """List tasks from ClickUp."""
    tasks = api.get_all_tasks(config.list_id, full_details=True)

    if args.filter:
        filter_lower = args.filter.lower()
        tasks = [t for t in tasks if filter_lower in t.name.lower()]

    if not tasks:
        print("No tasks found.")
        return 0

    # Sort by name for easier reading
    tasks.sort(key=lambda t: t.name.lower())

    print(f"Tasks in {config.list_name} ({len(tasks)}):\n")
    for task in tasks:
        priority_str = f"P{task.priority}" if task.priority else "P-"
        status_str = task.status[:12].ljust(12) if task.status else "unknown"
        print(f"  {task.id}  [{priority_str}] [{status_str}] {task.name}")

    return 0


def cmd_delete(api: ClickUpAPI, config, args) -> int:
    """Delete/archive tasks from ClickUp."""
    if not args.task_ids:
        print("Error: No task IDs provided.", file=sys.stderr)
        return 1

    # First, show what we're about to delete
    print("Tasks to delete:")
    tasks_to_delete = []
    for task_id in args.task_ids:
        try:
            task = api.get_task(task_id)
            tasks_to_delete.append(task)
            print(f"  {task.id}: {task.name}")
        except Exception as e:
            print(f"  {task_id}: ERROR - {e}", file=sys.stderr)

    if not tasks_to_delete:
        print("\nNo valid tasks to delete.")
        return 1

    # Confirm unless --force
    if not args.force:
        print(f"\nThis will archive {len(tasks_to_delete)} task(s). Continue? [y/N] ", end="")
        response = input().strip().lower()
        if response not in ("y", "yes"):
            print("Aborted.")
            return 0

    # Delete tasks
    print("\nDeleting tasks...")
    deleted = 0
    for task in tasks_to_delete:
        try:
            api.delete_task(task.id)
            print(f"  Archived: {task.id} - {task.name}")
            deleted += 1
        except Exception as e:
            print(f"  FAILED: {task.id} - {e}", file=sys.stderr)

    print(f"\nArchived {deleted}/{len(tasks_to_delete)} task(s).")
    return 0 if deleted == len(tasks_to_delete) else 1


def cmd_sync(api: ClickUpAPI, beads: BeadsClient, config, args, beads_dir: Path) -> int:
    """Run sync."""
    engine = SyncEngine(api, beads, config, verbose=args.verbose, beads_dir=beads_dir)

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


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Sync beads with ClickUp bidirectionally",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  clickup-sync                 # Run full sync (account from .beads/clickup.yaml)
  clickup-sync --status        # Check configuration
  clickup-sync -v              # Verbose output
  clickup-sync list            # List all ClickUp tasks
  clickup-sync list -f "bug"   # Filter tasks by keyword
  clickup-sync delete <id>     # Delete/archive a task
        """,
    )

    # Global options
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Verbose output",
    )

    # Subcommands
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # list command
    list_parser = subparsers.add_parser("list", help="List ClickUp tasks")
    list_parser.add_argument(
        "--filter", "-f",
        help="Filter tasks by keyword in name",
    )

    # delete command
    delete_parser = subparsers.add_parser("delete", help="Delete/archive ClickUp tasks")
    delete_parser.add_argument(
        "task_ids",
        nargs="*",
        help="Task IDs to delete",
    )
    delete_parser.add_argument(
        "--force",
        action="store_true",
        help="Skip confirmation prompt",
    )

    # Legacy options (when no subcommand)
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

    args = parser.parse_args()

    # Check for .beads directory
    beads_dir = Path(".beads")
    if not beads_dir.exists():
        print(
            "Error: Not a beads repository. Run 'bd init' first.",
            file=sys.stderr,
        )
        return 1

    # Load configuration (includes account)
    try:
        config = load_config(beads_dir)
    except ConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # Status mode
    if args.status:
        print(f"ClickUp List: {config.list_name} ({config.list_id})")
        print(f"Space: {config.space_name or config.space_id}")
        print(f"Account: {config.account}")
        print(f"Last sync: {config.last_sync or 'Never'}")
        return 0

    # Get API token from secrets file using config's account
    try:
        token = get_token(config.account)
    except TokenError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # Dry run mode (placeholder)
    if args.dry_run:
        print("Dry run mode - not fully implemented yet")
        print("Would sync with ClickUp list:", config.list_name)
        return 0

    # Initialize API client
    api = ClickUpAPI(token)

    # Handle subcommands
    if args.command == "list":
        return cmd_list(api, config, args)
    elif args.command == "delete":
        return cmd_delete(api, config, args)
    else:
        # Default: run sync
        beads = BeadsClient(cwd=".")
        return cmd_sync(api, beads, config, args, beads_dir)


if __name__ == "__main__":
    sys.exit(main())
