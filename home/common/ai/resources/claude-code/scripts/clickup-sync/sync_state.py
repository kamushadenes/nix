"""Sync state management with content hashing to prevent ping-pong loops."""

import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import yaml

try:
    from .models import Bead, ClickUpTask, BeadStatus
except ImportError:
    from models import Bead, ClickUpTask, BeadStatus

# Status normalization for hash consistency
STATUS_NORMALIZE = {
    BeadStatus.OPEN: "open",
    BeadStatus.IN_PROGRESS: "in_progress",
    BeadStatus.BLOCKED: "blocked",
    BeadStatus.CLOSED: "closed",
}

CLICKUP_STATUS_NORMALIZE = {
    "to do": "open",
    "open": "open",
    "backlog": "open",
    "in progress": "in_progress",
    "doing": "in_progress",
    "blocked": "blocked",
    "on hold": "blocked",
    "complete": "closed",
    "done": "closed",
    "closed": "closed",
}

SYNC_STATE_FILE = "clickup-sync-state.yaml"
SYNC_STATE_VERSION = 1


def compute_sync_hash(
    title: str,
    description: Optional[str],
    status: str,
    priority: int,
) -> str:
    """
    Compute hash of syncable fields.

    Args:
        title: Issue title
        description: Issue description
        status: Normalized status string
        priority: Priority (0-4)

    Returns:
        12-character hex hash
    """
    # Normalize fields
    title_norm = (title or "").strip()
    desc_norm = (description or "").strip()
    status_norm = status.lower().strip()
    priority_norm = str(priority)

    content = f"{title_norm}|{desc_norm}|{status_norm}|{priority_norm}"
    return hashlib.md5(content.encode()).hexdigest()[:12]


def compute_bead_hash(bead: Bead) -> str:
    """Compute sync hash from a Bead."""
    status = STATUS_NORMALIZE.get(bead.status, "open")
    return compute_sync_hash(
        title=bead.title,
        description=bead.description,
        status=status,
        priority=bead.priority,
    )


def compute_task_hash(task: ClickUpTask) -> str:
    """Compute sync hash from a ClickUp task."""
    status = CLICKUP_STATUS_NORMALIZE.get(task.status.lower(), "open")
    # Map ClickUp priority (1-4) to beads priority (0-4)
    priority_map = {1: 0, 2: 1, 3: 2, 4: 3, None: 4}
    bead_priority = priority_map.get(task.priority, 2)
    return compute_sync_hash(
        title=task.name,
        description=task.description,
        status=status,
        priority=bead_priority,
    )


def load_sync_state(beads_dir: Path = Path(".beads")) -> dict[str, dict]:
    """
    Load sync state from file.

    Args:
        beads_dir: Path to .beads directory

    Returns:
        Dict mapping bead_id -> {bead_hash, task_hash, last_synced}
    """
    state_path = beads_dir / SYNC_STATE_FILE

    if not state_path.exists():
        return {}

    try:
        with open(state_path) as f:
            data = yaml.safe_load(f) or {}

        if data.get("version") != SYNC_STATE_VERSION:
            # Version mismatch - reset state
            return {}

        return data.get("state", {})
    except (yaml.YAMLError, OSError):
        return {}


def save_sync_state(
    state: dict[str, dict],
    beads_dir: Path = Path(".beads"),
) -> None:
    """
    Save sync state to file.

    Args:
        state: Dict mapping bead_id -> {bead_hash, task_hash, last_synced}
        beads_dir: Path to .beads directory
    """
    state_path = beads_dir / SYNC_STATE_FILE

    data = {
        "version": SYNC_STATE_VERSION,
        "state": state,
    }

    with open(state_path, "w") as f:
        yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False)


def update_sync_state(
    state: dict[str, dict],
    bead_id: str,
    bead_hash: str,
    task_hash: str,
) -> None:
    """
    Update sync state for a bead after successful sync.

    Args:
        state: Sync state dict (modified in place)
        bead_id: Bead ID
        bead_hash: Current bead content hash
        task_hash: Current task content hash
    """
    state[bead_id] = {
        "bead_hash": bead_hash,
        "task_hash": task_hash,
        "last_synced": datetime.now(timezone.utc).isoformat(),
    }


def should_sync(
    bead: Bead,
    task: ClickUpTask,
    sync_state: dict[str, dict],
) -> tuple[bool, Optional[str]]:
    """
    Determine if sync is needed and in which direction.

    Uses content hashing to detect actual changes rather than
    relying solely on timestamps (which change on every sync).

    Args:
        bead: Local bead
        task: ClickUp task
        sync_state: Current sync state

    Returns:
        Tuple of (should_sync, direction)
        direction is "pull" (ClickUp -> bead) or "push" (bead -> ClickUp)
    """
    bead_hash = compute_bead_hash(bead)
    task_hash = compute_task_hash(task)

    # Content identical - no sync needed
    if bead_hash == task_hash:
        return False, None

    # Get last synced state
    last = sync_state.get(bead.id, {})
    last_bead_hash = last.get("bead_hash")
    last_task_hash = last.get("task_hash")

    # First sync (no previous state) - use timestamp as tiebreaker
    if last_bead_hash is None and last_task_hash is None:
        if bead.updated_at > task.date_updated:
            return True, "push"
        else:
            return True, "pull"

    # Detect which side changed
    bead_changed = bead_hash != last_bead_hash
    task_changed = task_hash != last_task_hash

    if bead_changed and not task_changed:
        return True, "push"  # Only bead changed
    elif task_changed and not bead_changed:
        return True, "pull"  # Only task changed
    elif bead_changed and task_changed:
        # Both changed - conflict! Use timestamp as tiebreaker
        if bead.updated_at > task.date_updated:
            return True, "push"
        else:
            return True, "pull"
    else:
        # Neither changed according to stored hashes, but content differs
        # This can happen if state was corrupted - use timestamp
        if bead.updated_at > task.date_updated:
            return True, "push"
        else:
            return True, "pull"
